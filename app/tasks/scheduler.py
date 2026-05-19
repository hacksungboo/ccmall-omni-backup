import os
import sys
import datetime
import subprocess

import boto3
import psycopg2
from psycopg2.extras import execute_values
from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger


# =========================
# 기본 환경변수
# =========================
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")

REC_DB_HOST = os.getenv("REC_DB_HOST")  
REC_DB_PORT = os.getenv("REC_DB_PORT", DB_PORT)
REC_DB_PASS = os.getenv("REC_DB_PASS", DB_PASS)

BACKUP_S3_BUCKET = os.getenv("BACKUP_S3_BUCKET")
LOCAL_BACKUP_DIR = "/tmp/db_backups"


# =========================
# DB 연결 함수
# =========================
def get_conn(host, password, port="5432"):
    return psycopg2.connect(
        host=host,
        port=port,
        dbname=DB_NAME,
        user=DB_USER,
        password=password
    )


# =========================
# 1. onprem 전체 DB → S3 백업
# =========================
def backup_full_db_to_s3():
    if not BACKUP_S3_BUCKET:
        raise RuntimeError("BACKUP_S3_BUCKET 환경변수가 설정되지 않았습니다.")

    os.makedirs(LOCAL_BACKUP_DIR, exist_ok=True)

    now = datetime.datetime.now()
    date_dir = now.strftime("%Y-%m-%d")
    timestamp = now.strftime("%H%M%S")

    filename = f"full_db_backup_{timestamp}.sql"
    local_path = os.path.join(LOCAL_BACKUP_DIR, filename)
    s3_key = f"backups/{date_dir}/{filename}"

    env = os.environ.copy()
    env["PGPASSWORD"] = DB_PASS

    dump_cmd = [
        "pg_dump",
        "-h", DB_HOST,
        "-p", DB_PORT,
        "-U", DB_USER,
        "-d", DB_NAME,
        "-f", local_path
    ]

    subprocess.run(
        dump_cmd,
        check=True,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    s3 = boto3.client("s3")
    s3.upload_file(local_path, BACKUP_S3_BUCKET, s3_key)

    if os.path.exists(local_path):
        os.remove(local_path)

    print(f"[S3 백업 완료] s3://{BACKUP_S3_BUCKET}/{s3_key}")


# =============================
# 2. inventorys 전체 동기화
# =============================
def sync_inventorys_to_rec():
    onprem_conn = get_conn(DB_HOST, DB_PASS, DB_PORT)
    rec_conn = get_conn(REC_DB_HOST, REC_DB_PASS, REC_DB_PORT)

    try:
        with onprem_conn.cursor() as cur:
            cur.execute("""
                SELECT item_id, item_name, quantity
                FROM inventorys
                ORDER BY item_id;
            """)
            rows = cur.fetchall()

        with rec_conn.cursor() as cur:
            execute_values(
                cur,
                """
                INSERT INTO inventorys (item_id, item_name, quantity)
                VALUES %s
                ON CONFLICT (item_id)
                DO UPDATE SET
                    item_name = EXCLUDED.item_name,
                    quantity = EXCLUDED.quantity;
                """,
                rows
            )

        rec_conn.commit()
        print(f"[REC 동기화 완료] inventorys {len(rows)}건 upsert")

    except Exception:
        rec_conn.rollback()
        raise

    finally:
        onprem_conn.close()
        rec_conn.close()


# =========================
# 3. 최근 3일 주문 고객 최소 정보 동기화
# =========================
def sync_recent_customers_to_rec():
    """
    orders 테이블에 customer_id FK가 있으면 필요함.
    REC orders가 customers를 참조하지 않는 구조라면 이 함수는 생략 가능.
    """
    onprem_conn = get_conn(DB_HOST, DB_PASS, DB_PORT)
    rec_conn = get_conn(REC_DB_HOST, REC_DB_PASS, REC_DB_PORT)

    try:
        with onprem_conn.cursor() as cur:
            cur.execute("""
                SELECT DISTINCT c.id, c.password, c.name, c.address
                FROM customers c
                JOIN orders o ON c.id = o.customer_id
                WHERE o.order_time >= NOW() - INTERVAL '3 days';
            """)
            rows = cur.fetchall()

        if not rows:
            print("[REC 동기화] 최근 3일 주문 고객 없음")
            return

        with rec_conn.cursor() as cur:
            execute_values(
                cur,
                """
                INSERT INTO customers (id, password, name, address)
                VALUES %s
                ON CONFLICT (id)
                DO UPDATE SET
                    password = EXCLUDED.password,
                    name = EXCLUDED.name,
                    address = EXCLUDED.address;
                """,
                rows
            )

        rec_conn.commit()
        print(f"[REC 동기화 완료] customers 최소 정보 {len(rows)}건 upsert")

    except Exception:
        rec_conn.rollback()
        raise

    finally:
        onprem_conn.close()
        rec_conn.close()


# =========================
# 4. orders 최근 3일 재적재
# =========================
def sync_recent_orders_to_rec():
    onprem_conn = get_conn(DB_HOST, DB_PASS, DB_PORT)
    rec_conn = get_conn(REC_DB_HOST, REC_DB_PASS, REC_DB_PORT)

    try:
        with onprem_conn.cursor() as cur:
            cur.execute("""
                SELECT order_id, item_id, customer_id, order_time, order_quantity
                FROM orders
                WHERE order_time >= NOW() - INTERVAL '3 days'
                ORDER BY order_id;
            """)
            rows = cur.fetchall()

        with rec_conn.cursor() as cur:
            # REC에는 최근 3일 주문만 유지
            cur.execute("DELETE FROM orders;")

            if rows:
                execute_values(
                    cur,
                    """
                    INSERT INTO orders (
                        order_id,
                        item_id,
                        customer_id,
                        order_time,
                        order_quantity
                    )
                    VALUES %s;
                    """,
                    rows
                )

        rec_conn.commit()
        print(f"[REC 동기화 완료] orders 최근 3일 {len(rows)}건 재적재")

    except Exception:
        rec_conn.rollback()
        raise

    finally:
        onprem_conn.close()
        rec_conn.close()


# =========================
# 5. 무결성 검증
# =========================
def verify_rec_sync():
    onprem_conn = get_conn(DB_HOST, DB_PASS, DB_PORT)
    rec_conn = get_conn(REC_DB_HOST, REC_DB_PASS, REC_DB_PORT)

    try:
        with onprem_conn.cursor() as cur:
            cur.execute("""
                SELECT COUNT(*), COALESCE(SUM(quantity), 0)
                FROM inventorys;
            """)
            onprem_inventory = cur.fetchone()

            cur.execute("""
                SELECT COUNT(*), COALESCE(SUM(order_quantity), 0)
                FROM orders
                WHERE order_time >= NOW() - INTERVAL '3 days';
            """)
            onprem_orders = cur.fetchone()

        with rec_conn.cursor() as cur:
            cur.execute("""
                SELECT COUNT(*), COALESCE(SUM(quantity), 0)
                FROM inventorys;
            """)
            rec_inventory = cur.fetchone()

            cur.execute("""
                SELECT COUNT(*), COALESCE(SUM(order_quantity), 0)
                FROM orders;
            """)
            rec_orders = cur.fetchone()

        print(f"[검증] inventorys onprem={onprem_inventory}, rec={rec_inventory}")
        print(f"[검증] orders     onprem={onprem_orders}, rec={rec_orders}")

        if onprem_inventory != rec_inventory:
            raise RuntimeError("inventorys 무결성 검증 실패")

        if onprem_orders != rec_orders:
            raise RuntimeError("orders 무결성 검증 실패")

        print("[검증 완료] REC 동기화 무결성 정상")

    finally:
        onprem_conn.close()
        rec_conn.close()


# =========================
# 전체 작업
# =========================
def run_daily_backup_job():
    print("==============================================")
    print(f"[{datetime.datetime.now()}] 일일 백업 작업 시작")
    print("==============================================")

    try:
        backup_full_db_to_s3()
        sync_inventorys_to_rec()
        sync_recent_customers_to_rec()
        sync_recent_orders_to_rec()
        verify_rec_sync()

        print(f"[{datetime.datetime.now()}] 일일 백업 작업 성공\n")

    except Exception as e:
        print(f"[오류] 일일 백업 작업 실패: {e}", file=sys.stderr)


if __name__ == "__main__":
    print("CCMall 자동 백업 시스템 시작")
    print(f"onprem-db: {DB_HOST}:{DB_PORT}/{DB_NAME}")
    print(f"ec2-rec:   {REC_DB_HOST}:{REC_DB_PORT}/{DB_NAME}")
    print(f"S3 bucket: {BACKUP_S3_BUCKET}")

    # 테스트용 즉시 1회 실행
    run_daily_backup_job()

    # 매일 새벽 1시 자동 실행
    scheduler = BlockingScheduler()
    scheduler.add_job(
        run_daily_backup_job,
        CronTrigger(hour=1, minute=0)
    )

    print("스케줄러 대기 중: 매일 01:00 자동 실행")
    scheduler.start()