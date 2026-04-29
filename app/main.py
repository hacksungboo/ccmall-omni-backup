from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from starlette.responses import FileResponse # Redirect 대신 FileResponse 추천
from .api import inventorys, orders
from .core.database import engine
from .models import schemas as models

# DB 테이블 생성
models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# API 라우터 등록
app.include_router(inventorys.router, prefix="/inventorys")
app.include_router(orders.router, prefix="/orders")

# [중요] 정적 파일 설정
# 현재 터미널 위치(루트) 기준으로 static 폴더를 연결
app.mount("/static", StaticFiles(directory="static"), name="static")

# 메인 주소(/)로 접속했을 때 index.html을 직접 던져주기
# app/main.py
@app.get("/")
async def read_index():
    return FileResponse("static/index.html") # 메인 메뉴(와이어프레임 중앙)