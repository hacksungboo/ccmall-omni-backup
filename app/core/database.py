from sqlalchemy import create_engine 
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# 리눅스 DB 주소
SQLALCHEMY_DATABASE_URL = "postgresql://ccmall_user:user1@172.16.8.201:5432/ccmall_db"

# 엔진 생성
engine = create_engine(SQLALCHEMY_DATABASE_URL)

# 세션 생성 도구
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 부모클래스 설정
Base = declarative_base()

# DB 연결 통로
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
        #test