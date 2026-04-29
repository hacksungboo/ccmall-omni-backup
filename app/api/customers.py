import os
from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import create_engine, Column, String, Date
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from typing import List

# 라우터 및 템플릿 설정
router = APIRouter()
templates = Jinja2Templates(directory="static")

# DB 설정
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://ccmall_user:user1@172.16.8.201:5432/ccmall_db")
engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

class Customer(Base):
    __tablename__ = "customers"
    id = Column(String(50), primary_key=True, index=True)
    password = Column(String(255), nullable=False)
    name = Column(String(50), nullable=False)
    birth_date = Column(Date, nullable=False)
    address = Column(String(50), nullable=False)
    email = Column(String(100), nullable=False)
    phone_number = Column(String(20), nullable=False)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- 페이지 렌더링 라우터 ---

# 1. 고객 목록 페이지 (아이디, 이름, 주소만 노출)
@router.get("/", response_class=HTMLResponse)
async def get_customers_list_page(request: Request, db: Session = Depends(get_db)):
    customers = db.query(Customer).all()
    return templates.TemplateResponse("customer.html", {"request": request, "customers": customers})

# 2. 고객 상세 페이지 (모든 정보 노출)
@router.get("/{member_id}", response_class=HTMLResponse)
async def get_customer_detail_page(request: Request, member_id: str, db: Session = Depends(get_db)):
    customer = db.query(Customer).filter(Customer.ID == member_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="고객을 찾을 수 없습니다.")
    return templates.TemplateResponse("customer_detail.html", {"request": request, "customer": customer})

# --- 순수 API 엔드포인트 (필요 시 유지) ---
@router.get("/api/list", response_model=List[dict])
def get_customer_api(db: Session = Depends(get_db)):
    return db.query(Customer).all()