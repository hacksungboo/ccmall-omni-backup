import os
from fastapi import FastAPI, Form, Depends, Response, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session

# 프로젝트 구조에 맞춘 임포트
from .api import inventorys, orders, customers
from .core.database import engine, get_db
from .models import schemas as models

# DB 테이블 생성
models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# 템플릿 설정 (static 폴더 사용)
templates = Jinja2Templates(directory="static")

# 라우팅 등록
app.include_router(inventorys.router, prefix="/inventorys")
app.include_router(orders.router, prefix="/orders")
app.include_router(customers.router, prefix="/customers")
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/", response_class=HTMLResponse)
async def read_index(request: Request, error: str = None): # error 파라미터 추가
    is_login = request.cookies.get("admin_session") == "true"
    
    # 에러 메시지 결정
    error_msg = "아이디 또는 비밀번호가 틀렸습니다." if error == "login_fail" else None
    
    return templates.TemplateResponse("index.html", {
        "request": request,
        "is_login": is_login,
        "error_msg": error_msg,
        "db_host": os.getenv("DB_HOST", "unknown")
    })

@app.post("/login")
async def login(username: str = Form(...), password: str = Form(...), db: Session = Depends(get_db)):
    admin = db.query(models.Admin).filter(models.Admin.username == username, models.Admin.password == password).first()

    if admin:
        res = RedirectResponse(url="/", status_code=303)
        res.set_cookie(key="admin_session", value="true", max_age=600)
        return res
    
    # [수정] 로그인 실패 시 URL 뒤에 에러 표시를 붙여서 보냄
    return RedirectResponse(url="/?error=login_fail", status_code=303)

@app.get("/logout")
async def logout():
    res = RedirectResponse(url="/")
    res.delete_cookie("admin_session")
    return res