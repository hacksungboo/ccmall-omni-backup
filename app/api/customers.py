from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy.orm import Session
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
# field_validator 추가 임포트
from pydantic import BaseModel, field_validator
from datetime import date
from typing import List
import re # 정규표현식 모듈 임포트

from ..core.database import get_db 
from ..models import schemas as models

router = APIRouter()
templates = Jinja2Templates(directory="static")

### 신규 고객 생성용
class CustomerCreate(BaseModel):
    id: str
    password: str    
    name: str
    birth_date: date
    address: str
    email: str
    phone_number: str

### 기존 고객 수정용
class CustomerUpdate(BaseModel):
    name: str
    birth_date: date
    address: str
    email: str
    phone_number: str

    @field_validator('email')
    @classmethod
    def validate_email(cls, v):
        if not re.match(r"^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$", v):
            raise ValueError("유효한 이메일 형식이 아닙니다.")
        return v

    @field_validator('phone_number')
    @classmethod
    def validate_phone(cls, v):
        if not re.match(r"^\d{2,3}-\d{3,4}-\d{4}$", v):
            raise ValueError("전화번호는 xxx-xxxx-xxxx 형식이어야 합니다.")
        return v

### 고객 리스트 조회 및 검색
@router.get("/", response_class=HTMLResponse)
async def get_customers_list_page(
    request: Request, 
    search_type: str = None, 
    search_value: str = None, 
    customer_id: str = None, 
    db: Session = Depends(get_db)
):
    if customer_id:
        customer = db.query(models.Customer).filter(models.Customer.id == customer_id).first()
        if not customer:
            raise HTTPException(status_code=404, detail="고객을 찾을 수 없습니다.")
        
        return templates.TemplateResponse("customers.html", {
            "request": request, 
            "customer": customer, 
            "mode": "detail" 
        })

    query = db.query(models.Customer)
    if search_type and search_value:
        search_filter = f"%{search_value}%"
        if search_type == "id":
            query = query.filter(models.Customer.id.like(search_filter))
        elif search_type == "name":
            query = query.filter(models.Customer.name.like(search_filter))
        elif search_type == "addr":
            query = query.filter(models.Customer.address.like(search_filter))
            
    customers = query.all()
    
    return templates.TemplateResponse("customers.html", {
        "request": request, 
        "customers": customers, 
        "search_type": search_type, 
        "search_value": search_value,
        "mode": "list"
    })

### 고객 상세 정보 제공 API
@router.get("/{member_id}")
async def get_customer_detail_api(
    member_id: str, 
    db: Session = Depends(get_db)
):
    customer = db.query(models.Customer).filter(models.Customer.id == member_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="고객을 찾을 수 없습니다.")
    
    return {
        "id": customer.id,
        "name": customer.name,
        "email": customer.email,
        "address": customer.address,
        "phone_number": customer.phone_number,
        "birth_date": str(customer.birth_date)
    }

### 신규 고객 추가 API
@router.post("/")
async def create_customer(customer: CustomerCreate, db: Session = Depends(get_db)):
    existing_user = db.query(models.Customer).filter(models.Customer.id == customer.id).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="이미 존재하는 아이디입니다.")

    try:
        new_customer = models.Customer(**customer.dict())
        db.add(new_customer)
        db.commit()
        db.refresh(new_customer)
        return {"message": "고객이 성공적으로 추가되었습니다.", "id": new_customer.id}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"DB 저장 실패: {str(e)}")

### 고객 정보 수정 API
@router.put("/{member_id}")
async def update_customer(member_id: str, customer_data: CustomerUpdate, db: Session = Depends(get_db)):
    customer = db.query(models.Customer).filter(models.Customer.id == member_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="고객을 찾을 수 없습니다.")
    try:
        # password 업데이트 로직을 완전히 제거했습니다.
        customer.name = customer_data.name
        customer.email = customer_data.email
        customer.address = customer_data.address
        customer.phone_number = customer_data.phone_number
        customer.birth_date = customer_data.birth_date
        
        db.commit()
        return {"message": "고객 정보가 수정되었습니다."}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"DB 수정 실패: {str(e)}")

#### 고객 삭제 API
@router.delete("/{member_id}")
async def delete_customer(member_id: str, db: Session = Depends(get_db)):
    customer = db.query(models.Customer).filter(models.Customer.id == member_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="삭제 대상을 찾을 수 없습니다.")

    existing_order = db.query(models.Order).filter(models.Order.customer_id == member_id).first()
    if existing_order:
        raise HTTPException(
            status_code=400, 
            detail="해당 고객의 주문 내역이 존재하여 삭제할 수 없습니다. 먼저 주문 내역을 처리해주세요."
        )
    try:
        db.delete(customer)
        db.commit()
        return {"message": "고객 정보가 삭제되었습니다."}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"DB 삭제 실패: {str(e)}")