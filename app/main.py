from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from starlette.responses import FileResponse # Redirect 대신 FileResponse 추천
from .api import inventorys, orders, customers
from .core.database import engine
from .models import schemas as models

# DB 테이블 생성 (이미 존재하는 테이블은 무시됨)
models.Base.metadata.create_all(bind=engine)

app = FastAPI()

# API 라우터 등록
app.include_router(inventorys.router, prefix="/inventorys")
app.include_router(orders.router, prefix="/orders")
app.include_router(customers.router, prefix="/customers")
# [중요] 정적 파일 설정
app.mount("/static", StaticFiles(directory="static"), name="static")

# 메인 주소(/)로 접속했을 때 index.html 호출
@app.get("/")
async def read_index():
    # 경로가 맞는지 확인 필요 (static 폴더가 루트에 있다면 "static/index.html")
    return FileResponse("static/index.html")