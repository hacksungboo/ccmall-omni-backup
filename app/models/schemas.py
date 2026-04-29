# [DB Models] SQLAlchemy 기반의 데이터베이스 테이블 구조 정의 (테이블 스키마)
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from ..core.database import Base # database.py에서 정의한 Base를 가져옵니다.

# [DB Model] inventorys 테이블 매칭
class Inventory(Base):
    __tablename__ = "inventorys"

    item_id = Column(Integer, primary_key=True, index=True)
    item_name = Column(String)
    quantity = Column(Integer)

# [DB Model] orders 테이블 매칭
class Order(Base):
    __tablename__ = "orders"

    order_id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    item_id = Column(Integer, ForeignKey("inventorys.item_id"))
    customer_id = Column(String)
    order_time = Column(DateTime)
    #test