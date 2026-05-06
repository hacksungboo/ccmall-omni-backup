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
    edit_id: int = None, 
    db: Session = Depends(get_db)
):

    query = db.query(models.Inventory).order_by(models.Inventory.item_id)
    
    if search_input:
        query = query.filter(models.Inventory.item_name.contains(search_input))
    
    items = query.all()
    return templates.TemplateResponse("inventorys.html", {
        "request": request, 
        "items": items, 
        "edit_id": edit_id
    })

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