# [API] /inventorys
# Table: inventorys (item_id, item_name, quantity)
# 기능: 상품 목록 조회 및 재고 상태 관리
# [API] /inventorys - 상품 재고 조회 전용 엔드포인트



from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from ..core.database import get_db
from ..models import schemas as models

router = APIRouter()
templates = Jinja2Templates(directory="static")

# [수정] 페이지 렌더링 및 검색 기능 통합
@router.get("/", response_class=HTMLResponse)
async def read_inventorys_page(
    request: Request, 
    search_input: str = None, 
    db: Session = Depends(get_db)
):
    query = db.query(models.Inventory)
    
    # 검색어가 있을 경우 상품명(item_name) 필터링
    if search_input:
        query = query.filter(models.Inventory.item_name.contains(search_input))
    
    items = query.all()
    return templates.TemplateResponse("inventorys.html", {"request": request, "items": items})

# 상세 페이지 라우터
@router.get("/{item_id}", response_class=HTMLResponse)
async def read_inventory_detail_page(request: Request, item_id: int, db: Session = Depends(get_db)):
    db_item = db.query(models.Inventory).filter(models.Inventory.item_id == item_id).first()
    if not db_item:
        raise HTTPException(status_code=404, detail="상품 정보를 찾을 수 없습니다.")
    
    return templates.TemplateResponse("inventorys_detail.html", {"request": request, "item": db_item})