# [API] /orders
# Table: orders (order_id, item_id, customer_id, order_time)
# 기능: 주문 생성 및 고객별 주문 내역 조회
# [API] /orders - 수량 반영 버전


# [API] /orders - 주문 관리 엔드포인트
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from ..core.database import get_db
from ..models import schemas as models

# (router 정의)
router = APIRouter()

@router.get("/")
def read_orders(db: Session = Depends(get_db)):
    orders = db.query(models.Order).all()
    return orders


@router.post("/")
def create_order(item_id: int, customer_id: str, count: int, db: Session = Depends(get_db)):
    item = db.query(models.Inventory).filter(models.Inventory.item_id == item_id).first()
    
    
    if item.quantity < count:
        raise HTTPException(status_code=400, detail=f"재고가 부족합니다. (현재 재고: {item.quantity})")
    
   
    new_order = models.Order(
        item_id=item_id,
        customer_id=customer_id,
        order_quantity=count,  
        order_time=datetime.now()
    )
    
    db.add(new_order)
    db.commit()
    db.refresh(new_order)
    
    return {"message": f"{count}개 주문 완료!"}
#test