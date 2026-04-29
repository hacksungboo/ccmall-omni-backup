
import os
from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy import create_engine, Column, String, Date
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import List
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://ccmall_user:user1@172.16.8.201:5432/ccmall_db")
engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Customer(Base):
    __tablename__ = "CUSTOMERS"
    ID = Column(String(50), primary_key=True, index=True)
    PW = Column(String(255), nullable=False)
    NAME = Column(String(50), nullable=False)
    BIRTH = Column(Date, nullable=False)
    ADDR = Column(String(50), nullable=False)
    EMAIL = Column(String(100), nullable=False)
    PHONE = Column(String(20), nullable=False)
    

Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
 
 
        
@app.get("/api/customers", response_model=List[dict])
def get_customer_list(db: Session = Depends(get_db)):
    return db.query(Customer).all()




@app.get("/api/customers/{member_id}") ### 컬럼별 검색기능 추가예정
def get_member_detail(member_id: str, db: Session = Depends(get_db)):
    customer = db.query(Customer).filter(Customer.ID == member_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="해당 고객을 찾을 수 없습니다.")
    return customer
