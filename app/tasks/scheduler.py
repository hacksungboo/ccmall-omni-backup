import boto3
import subprocess
import datetime
import os
import sys
from sqlalchemy import delete
from sqlalchemy.orm import Session
from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger

# [주의] DB 모델 및 세션 설정은 본인의 프로젝트 경로에 맞게 임포트하세요.
# from app.core.database import SessionLocal 
# from app.models.schema import Order

# =========================================================
# 1. 환경 설정 (수정된 부분)
# =========================================================
DB_NAME = "ccmall_db"
DB_USER = "ccmall_user"

# [수정 1] 데이터를 '뽑아낼' 원본 DB (온프레미스 로컬 DB)
DB_HOST = "172.16.8.201"  

# [수정 2] 실제 로컬 DB 비밀번호로 변경 (기존 ccmall_password -> user1)
DB_PASS = "user1"  

# [수정 3] 환경변수 충돌 방지를 위해 확인된 S3 버킷명으로 하드코딩 고정
BUCKET_NAME = "ccmall-bucket-99a9" 
LOCAL_BACKUP_DIR = "/tmp/db_backups"

def run_integrated_backup_process():
    now = datetime.datetime.now()
    three_months_ago = now - datetime.timedelta(days=90)
    timestamp = now.strftime("%Y%m%d_%H%M%S")
    filename = f"ccmall_full_{timestamp}.sql"
    local_path = os.path.join(LOCAL_BACKUP_DIR, filename)
    
    print(f"[{now.strftime('%Y-%m-%d %H:%M:%S')}] 🚀 데이터 백업 및 자동 동기화 프로세스 시작")

    # [1단계] 로컬 임시 디렉토리 생성
    if not os.path.exists(LOCAL_BACKUP_DIR):
        os.makedirs(LOCAL_BACKUP_DIR)

    # [2단계] pg_dump 실행 (로컬 DB -> 파일)
    try:
        os.environ["PGPASSWORD"] = DB_PASS 
        subprocess.run(
            f"pg_dump -h {DB_HOST} -U {DB_USER} -d {DB_NAME} -f {local_path}", 
            shell=True, check=True
        )
        print(f"  ✅ [백업] 로컬 DB 덤프 완료: {local_path}")
    except subprocess.CalledProcessError as e:
        print(f"  ❌ [백업] DB 덤프 실패 (네트워크/비밀번호 확인 필요): {e}", file=sys.stderr)
        return

    # [3단계] S3 업로드 (boto3)
    try:
        s3 = boto3.client('s3')
        s3_key = f"backups/cold/{now.strftime('%Y-%m')}/{filename}"
        s3.upload_file(local_path, BUCKET_NAME, s3_key)
        print(f"  ✅ [보관] S3 업로드 성공 (Cold Archive): {s3_key}")
    except Exception as e:
        print(f"  ❌ [보관] AWS S3 업로드 에러 (IAM 권한 확인 필요): {e}", file=sys.stderr)
        return

    # =========================================================
    # [추가] 3.5단계: 예비 DB(EC2-Rec)로 자동 동기화 (Restore)
    # =========================================================
    REC_DB_HOST = "10.0.2.30"  # 데이터를 밀어넣을 예비 DB IP
    REC_DB_PASS = "user1"      # 예비 DB 비밀번호

    try:
        print(f"  🔄 [동기화] 예비 DB 서버({REC_DB_HOST})로 데이터 복제 중...")
        os.environ["PGPASSWORD"] = REC_DB_PASS 
        
        # psql을 이용해 방금 만든 sql 파일을 예비 DB에 실행(밀어넣기)
        subprocess.run(
            f"psql -h {REC_DB_HOST} -U {DB_USER} -d {DB_NAME} -f {local_path}", 
            shell=True, check=True, stdout=subprocess.DEVNULL
        )
        print(f"  ✅ [동기화] 예비 DB 세팅 완료! 언제든 Failover가 가능합니다. 🛡️")
    except subprocess.CalledProcessError as e:
        print(f"  ❌ [동기화] 예비 DB 동기화 실패: {e}", file=sys.stderr)
    # =========================================================

    # [4단계] 3개월 이전 데이터 정리 (주석 처리됨)
    """
    db: Session = SessionLocal()
    try:
        stmt = delete(Order).where(Order.order_time < three_months_ago)
        result = db.execute(stmt)
        db.commit()
        print(f"  ✅ {three_months_ago} 이전 콜드 데이터({result.rowcount}건) 정리 완료.")
    except Exception as e:
        db.rollback()
        print(f"  ❌ DB 정리 중 오류: {e}")
    finally:
        db.close()
    """

    # [5단계] 로컬 임시 파일 삭제
    if os.path.exists(local_path):
        os.remove(local_path)
        print(f"  🗑️  로컬 임시 파일({filename}) 청소 완료.")
    
    print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] ✨ 모든 공정이 완벽하게 종료되었습니다.\n")

if __name__ == "__main__":
    # 테스트 모드: 즉시 1회 실행하여 작동 여부 확인
    print("--- 테스트 모드: 백업 및 동기화를 즉시 1회 실행합니다 ---")
    run_integrated_backup_process() 

    # 정기 스케줄러 가동 (매일 01:00)
    scheduler = BlockingScheduler()
    scheduler.add_job(
        run_integrated_backup_process, 
        'cron', 
        hour=1, 
        minute=0,
        id="daily_backup_job"
    )

    print("==============================================")
    print("      CCmall 자동 백업 & Failover 준비 시스템      ")
    print("==============================================")
    print("스케줄: 매일 오전 01:00 자동 실행 대기 중...")
    
    try:
        scheduler.start()
    except (KeyboardInterrupt, SystemExit):
        print(" 스케줄러 종료")