from fastapi import APIRouter, Depends, HTTPException, Request, Form
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy.orm import Session
from ..core.database import get_db
from ..models import schemas as models

router = APIRouter()
templates = Jinja2Templates(directory="static")


@router.get("/", response_class=HTMLResponse)
async def read_inventorys_page(
    request: Request, 
    search_input: str = None, 
    edit_id: int = None,  # 수정 버튼 누른 행의 ID를 받음
    db: Session = Depends(get_db)
):
    # [정렬 추가] .order_by(models.Inventory.item_id)로 ID순 정렬
    query = db.query(models.Inventory).order_by(models.Inventory.item_id)
    
    if search_input:
        query = query.filter(models.Inventory.item_name.contains(search_input))
    
    items = query.all()
    # edit_id를 템플릿에 전달해서 어떤 행을 편집창으로 보여줄지 결정
    return templates.TemplateResponse("inventorys.html", {
        "request": request, 
        "items": items, 
        "edit_id": edit_id
    })

# 추가(add)와 수정(update) 로직은 그대로 유지 (단, 리다이렉트 경로 확인)
@router.post("/add")
async def add_inventory(item_name: str = Form(...), quantity: int = Form(...), db: Session = Depends(get_db)):
    new_item = models.Inventory(item_name=item_name, quantity=quantity)
    db.add(new_item)
    db.commit()
    return RedirectResponse(url="/inventorys/", status_code=303)

@router.post("/update/{item_id}")
async def update_inventory(item_id: int, item_name: str = Form(...), quantity: int = Form(...), db: Session = Depends(get_db)):
    item = db.query(models.Inventory).filter(models.Inventory.item_id == item_id).first()
    if item:
        item.item_name = item_name
        item.quantity = quantity
        db.commit()
    return RedirectResponse(url="/inventorys/", status_code=303)