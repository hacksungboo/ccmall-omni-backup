# database.py

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

# DB 접속 정보
DB_URL = "postgresql://scott:tiger@172.16.8.101/scott_db"

# DB 엔진 만들기
engine=create_engine(DB_URL)
# 세션 만들기
SessionLocal=sessionmaker(autocommit=False, autoflush=False, bind=engine)
# 글 목록기능 (post)
CREATE_POST_TABLE="""
    CREATE TABLE IF NOT EXISTS post(
        num SERIAL PRIMARY KEY,
        writer VARCHAR(50) NOT NULL,
        title VARCHAR(100),
        content TEXT,
        created_at TIMESTAMP NOT NULL DEFAULT NOW()
    
    )
"""
# DB 연결시 테이블 없으면 만들기
with engine.connect() as connection:
    connection.execute(text(CREATE_POST_TABLE))
    connection.commit()



# DB 객체를 리턴해주는 함수 (main.py 등에서 import 해서 사용할 예정)
def get_db():
    db=SessionLocal()
    try:
        yield db
    finally:
        db.close()
