from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from starlette.responses import FileResponse # Redirect 대신 FileResponse 추천
from .api import inventorys, orders, customers
from .core.database import engine
from .models import schemas as models

models.Base.metadata.create_all(bind=engine)

app = FastAPI()

app.include_router(inventorys.router, prefix="/inventorys")
app.include_router(orders.router, prefix="/orders")
app.include_router(customers.router, prefix="/customers")
app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
async def read_index():
    return FileResponse("static/index.html")

