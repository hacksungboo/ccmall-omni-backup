from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy import create_engine, Column, String, Date
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import List

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://ccmall_user:user1@172.16.8.201:5432/ccmall_db")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class Customer(Base):
    __tablename__ = "CUSTOMERS"
    ID = COLUMN(STRING(50) , PRIMARY_KEY = TRUE, INDEX =TRUE)
    PW = COLUMN(STRING(255), NULLABLE = FALSE)
    NAME = COLUMN(STRING(50) , NULLABLE = FALSE)
    BIRTH = COLUMN(DATE, NULLABLE = FALSE)
    ADDR = COLUMN(STRING(50), NULLABLE = FALSE)
    EMAIL = COLUMN(STRING(100), NULLABLE = FALSE)
    PHONE = COLUMN(STRING(20), NULLABLE = FALSE)
    
Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
        
@app.get("/api/customers", response_model = Lsit[dict])
def get_customer_list(db:Session = Depends(get_db)):
    customers = db.query(Customer).all()
    return customers

@app.get("/api/customers/{member_id}")  ### 컬럼선택후 검색기능 추가예정 
def get_member_detail(member_id: str, db: Session = Depends(get_db)):
    customers = db.query(Customer).filter(Customer.id == customers.id).first()
    if not customers:
        raise HTTPException(status_code=404, detail="해당 고객을 찾을 수 없습니다.")
    return customers