from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, date
from pydantic import BaseModel
from ..core.database import get_db
from ..models import schemas as models

class CustomerCreate(BaseModel):
    ID: str
    PW: str
    NAME: str
    EMAIL: str
    PHONE: str
    ADDR: str
    BIRTH: date

router = APIRouter(
    prefix="/api/customers",
    tags=["customers"]
)

@router.get("/") 
def get_customer_list(db: Session = Depends(get_db)):
    customers = db.query(models.Customer).all()
    return [{"ID": c.ID, "NAME": c.NAME, "EMAIL": c.EMAIL, "PHONE": c.PHONE} for c in customers]

@router.get("/{member_id}")
def get_member_detail(member_id: str, db: Session = Depends(get_db)):
    c = db.query(models.Customer).filter(models.Customer.ID == member_id).first()
    if not c:
        raise HTTPException(status_code=404, detail="해당 고객을 찾을 수 없습니다.")
    return {
        "ID": c.ID, "NAME": c.NAME, "EMAIL": c.EMAIL, "PHONE": c.PHONE, 
        "ADDR": c.ADDR, "BIRTH": str(c.BIRTH)
    }
    
@router.post("/")
def create_customer(customer: CustomerCreate, db: Session = Depends(get_db)):
    customer_data = customer.dict() 
    db_customer = models.Customer(**customer_data)
    
    db.add(db_customer)
    db.commit()
    
    return {"message": "고객 정보 추가 완료"}
