import boto3
import subprocess
import datetime
import os
import sys
from sqlalchemy import delete
from sqlalchemy.orm import Session
from apscheduler.schedulers.blocking import BlockingScheduler
from apscheduler.triggers.cron import CronTrigger

# ==========================================
# 환경 변수 설정
# ==========================================
DB_NAME = os.getenv("DB_NAME", "ccmall_db")
DB_USER = os.getenv("DB_USER", "ccmall_user")
DB_PASS = os.getenv("DB_PASS", "user1")
DB_HOST = os.getenv("DB_HOST", "172.16.8.201")  # 온프레미스 DB 호스트

# .bashrc에 저장하신 BACKUP_S3_BUCKET 환경변수를 읽어옵니다.
BUCKET_NAME = os.getenv("BACKUP_S3_BUCKET") 
###   print(BUCKET_NAME)  --- 테스트용 s3 버킷 이름 출력 코드 마지막에 삭제예정
# 복구 및 동기화 대상 (예비 DB) 정보
<<<<<<< HEAD
<<<<<<< HEAD
REC_DB_HOST = os.getenv("REC_DB_HOST", "100.68.1.23")
=======
REC_DB_HOST = os.getenv("REC_DB_HOST", "100.120.245.81")
>>>>>>> df906ad (수정)
=======
REC_DB_HOST = os.getenv("REC_DB_HOST", "100.115.3.62")
>>>>>>> d2a6e24 (ccmall-rec 프로비저닝시 db환경 구축 및 장애발생시  ccmall-recovery-2 ec2 생성 수정)
REC_DB_PASS = os.getenv("REC_DB_PASS", "user1")

LOCAL_BACKUP_DIR = "/tmp/db_backups"

def run_integrated_backup_process():
    # S3 버킷 환경변수 체크
    if not BUCKET_NAME:
        print(f" 🚨 [오류] BACKUP_S3_BUCKET 환경변수가 설정되지 않았습니다. (현재 값: None)", file=sys.stderr)
        print("터미널에서 'export BACKUP_S3_BUCKET=진짜_버킷_이름'을 실행해주세요.", file=sys.stderr)
        return

    now = datetime.datetime.now()
    
    # ---------------------------------------------------------
    # [핵심 변경] 파일명을 타임스탬프 대신 고정된 이름으로 설정 (덮어쓰기용)
    # ---------------------------------------------------------
    filename = "full_db_backup.sql"
    local_path = os.path.join(LOCAL_BACKUP_DIR, filename)
    
    # S3에 저장될 경로 (폴더/파일명)
    s3_key = f"backups/{filename}"

    # 임시 폴더 생성
    if not os.path.exists(LOCAL_BACKUP_DIR):
        os.makedirs(LOCAL_BACKUP_DIR)

    # [1단계] 로컬 DB 덤프 (백업)
    try:
        os.environ["PGPASSWORD"] = DB_PASS
        dump_command = f"pg_dump -h {DB_HOST} -U {DB_USER} -d {DB_NAME} -f {local_path}"
        subprocess.run(dump_command, shell=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        print(f"   [백업] 로컬 DB 덤프 완료: {local_path}")
    except subprocess.CalledProcessError as e:
        print(f"   [오류] 로컬 DB 덤프 실패: {e.stderr.decode('utf-8')}", file=sys.stderr)
        return

    # [2단계] S3 업로드
    try:
        s3 = boto3.client('s3')
        s3.upload_file(local_path, BUCKET_NAME, s3_key)
        print(f"   [보관] AWS S3 업로드 성공: s3://{BUCKET_NAME}/{s3_key}")
    except Exception as e:
        print(f"   [오류] AWS S3 업로드 에러: {e}", file=sys.stderr)
        return

    # [3단계] 예비 DB(EC2-Rec)로 자동 동기화 (Restore)
    try:
        print(f"   [동기화] 예비 DB 서버({REC_DB_HOST})로 데이터 복제 중...")
        os.environ["PGPASSWORD"] = REC_DB_PASS 
        
        subprocess.run(
            f"psql -h {REC_DB_HOST} -U {DB_USER} -d {DB_NAME} -f {local_path}", 
            shell=True, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE
        )
        print(f"   [동기화] 예비 DB 세팅 완료! Failover 준비 완료. ")
    except subprocess.CalledProcessError as e:
        print(f"   [오류] 예비 DB 동기화 실패: {e.stderr.decode('utf-8') if e.stderr else e}", file=sys.stderr)

    # [4단계] 로컬 임시 파일 삭제
    if os.path.exists(local_path):
        os.remove(local_path)
        print(f"   [청소] 로컬 임시 파일({filename}) 삭제 완료.")
    
    print(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] 자동 백업/동기화 프로세스 종료되었습니다.\n")


if __name__ == "__main__":
    print("==============================================")
    print("      CCmall 자동 백업 & 동기화 시스템        ")
    print("==============================================")
    print(f"대상 버킷: {BUCKET_NAME}")
    
    # 테스트 모드: 즉시 1회 실행
    print("--- 테스트 모드: 환경변수 기반 백업 및 동기화 즉시 실행 ---")
    run_integrated_backup_process() 

    # 정기 스케줄러 가동 (매일 01:00)
    print("스케줄: 매일 오전 01:00 자동 실행 대기 중...")
    scheduler = BlockingScheduler()
    scheduler.add_job(
        run_integrated_backup_process,
        CronTrigger(hour=1, minute=0)
    )
    
    try:
        scheduler.start()
    except KeyboardInterrupt:
        print("스케줄러가 수동으로 종료되었습니다.")