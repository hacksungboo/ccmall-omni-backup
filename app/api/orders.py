from fastapi import APIRouter, Depends, HTTPException, Request, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from ..core.database import get_db
from ..models import schemas as models

router = APIRouter()
templates = Jinja2Templates(directory="static")

# [조회 & 검색]
@router.get("/", response_class=HTMLResponse)
async def read_orders_page(
    request: Request, 
    search_type: str = "customer_id", 
    search_input: str = None, 
    order_id: int = None, 
    db: Session = Depends(get_db)
):
    # 1. 상세 보기 모드 (이 부분은 기존과 동일)
    if order_id:
        order = db.query(models.Order).filter(models.Order.order_id == order_id).first()
        if not order:
            raise HTTPException(status_code=404, detail="내역 없음")
        customer = db.query(models.Customer).filter(models.Customer.id == order.customer_id).first()
        item = db.query(models.Inventory).filter(models.Inventory.item_id == order.item_id).first()
        return templates.TemplateResponse("orders.html", {
            "request": request, "order": order, "customer": customer, "item": item, "mode": "detail"
        })

    # 2. 목록 및 검색 모드 (Join 추가로 제품명 가져오기!)
    # Order와 Inventory를 조인해서 한꺼번에 가져옵니다.
    query = db.query(models.Order, models.Inventory).join(
        models.Inventory, models.Order.item_id == models.Inventory.item_id
    )
    
    if search_input:
        if search_type == "customer_id":
            query = query.filter(models.Order.customer_id.contains(search_input))
        elif search_type == "item_name":
            try:
                query = query.filter(models.Inventory.item_name.contains(search_input))
            except:
                pass
            
    # 조인된 결과는 (Order객체, Inventory객체) 튜플 형태로 리스트에 담깁니다.
    orders_with_items = query.all()
    
    return templates.TemplateResponse("orders.html", {
        "request": request, 
        "orders_with_items": orders_with_items, # 변수명 변경
        "mode": "list"
    })

# [취소 & 재고 복구] - POST 방식 (JS 미사용)
@router.post("/delete/{order_id}")
async def cancel_order(order_id: int, db: Session = Depends(get_db)):
    order = db.query(models.Order).filter(models.Order.order_id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="삭제 대상을 찾을 수 없음")

    try:
        # 재고 복구
        item = db.query(models.Inventory).filter(models.Inventory.item_id == order.item_id).first()
        if item:
            item.quantity += order.order_quantity
        
        db.delete(order)
        db.commit()
        return RedirectResponse(url="/orders/", status_code=303)
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail="서버 처리 오류")