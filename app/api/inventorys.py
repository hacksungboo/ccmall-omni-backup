# [API] /inventorys
# Table: inventorys (item_id, item_name, quantity)
# 기능: 상품 목록 조회 및 재고 상태 관리
# [API] /inventorys - 상품 재고 조회 전용 엔드포인트



from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..core.database import get_db
from ..models import schemas as models  # 테이블 정의 모델

router = APIRouter()


@router.get("/")
def read_inventorys(db: Session = Depends(get_db)):
    items = db.query(models.Inventory).all()
    return items

@router.get("/{item_id}")
def read_inventory_detail(item_id: int, db: Session = Depends(get_db)):
    
    db_item = db.query(models.Inventory).filter(models.Inventory.item_id == item_id).first()
    
    if not db_item:
        raise HTTPException(status_code=404, detail="상품 정보를 찾을 수 없습니다.")
    
   
    return {
        "item_id": db_item.item_id,      
        "item_name": db_item.item_name,  
        "quantity": db_item.quantity     
    }
#test