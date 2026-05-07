import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_read_customers_page():
    response = client.get("/customers/")
    assert response.status_code == 200
    assert "text/html" in response.headers["content-type"]

def test_read_inventorys_page():
    response = client.get("/inventorys/")
    assert response.status_code == 200

def test_read_orders_page():
    response = client.get("/orders/")
    assert response.status_code == 200