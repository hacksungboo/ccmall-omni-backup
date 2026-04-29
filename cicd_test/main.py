# main.py


from fastapi import Depends, FastAPI, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from fastapi.templating import Jinja2Templates
from sqlalchemy import text
from sqlalchemy.orm import Session

from database import get_db

# fastapi 객체 생성
app=FastAPI()
# jinja2 템플릿 객체 생성 (templates 파일들이 어디에 있는지 알려야 한다.)
templates=Jinja2Templates(directory="templates")


@app.get("/",response_class=HTMLResponse)
def index(request:Request):
    return templates.TemplateResponse(
        request=request,
        name="index.html",
        # 응답에 필요한 data 를 context로 전달할 수 있다.
        context={
            "fortuneToday":"동쪽으로 가면 귀인을 만나요"

        }
    )

# get 방식 /post 요청 처리
@app.get("/post", response_class=HTMLResponse)
def getPosts(request: Request, db:Session = Depends(get_db)):
    # DB 에서 글목록을 가져오기 위한 sql 문 준비
    query = text("""
        SELECT num, writer, title, content, created_at
        FROM post
        ORDER BY num DESC
    """)
    # 글 목록을 얻어와사 
    result = db.execute(query)
    posts = result.fetchall()
    # 응답하기
    return templates.TemplateResponse(
        request=request,
        name="post/list.html", # templates/post/list.html jinja2 를 해석한 결과를 응답
        context={
            "posts":posts
        }
    )


@app.get("/post/new",response_class=HTMLResponse)
def postNewForm(request:Request):
    return templates.TemplateResponse(request=request,name="post/new-form.html")

@app.post("/post/new")
def postNew(request:Request, writer: str = Form(...), title: str = Form(...), content: str = Form(...),
            db: Session = Depends(get_db)):
    # DB 에 저장할 sql 문  준비
    query = text("""
        INSERT INTO post
        (writer, title, content)
        VALUES(:writer, :title, :content)
    """)
    # query 문을 실행하면서 같이 전달한 dict의 키값과 :writer, :title, :content 동일한 위치에 값이 바인딩되어서 실행된다.
    db.execute(query, {"writer":writer, "title":title, "content":content})
    db.commit()

    # 특정 경로로 요청을 다시 하도록 리다일렉트 응답을 준다. 
    return templates.TemplateResponse(
        request=request,
        name="post/alert.html",
        context={
            "msg":"글 정보를 추가 했습니다!",
            "url":"/post"
        }
    )
@app.get("/post/delete/{num}") # {num} 경로 변수 선언 (path variable)
def delete(num:int,db:Session=Depends(get_db)): # 경로 변수의 이름과 함수의 매개변수의 이름을 일치시킨다
    # num 에는 삭제할 글의 번호가 들어 있다.
    query=text("DELETE FROM post WHERE num=:num")
    db.execute(query,{"num":num})
    db.commit()
    # 클라이언트가 /post로 다시 요청하라고 강요하기
    return RedirectResponse("/post",status_code=302)

@app.get("/post/edit/{num}")
def editForm(num:int,request:Request, db:Session=Depends(get_db)):
    # 수정할 글정보를 읽어오기 위한 query 작성
    query=text("""
        SELECT num, writer,content, created_at  
        FROM post
        WHERE num=:num
    """)
    # PK를 이용해서 select 하는 것이기 때문에 row는 1개다. 따라서, .fetchone() 함수를 호출한다.
    row=db.execute(query,{"num":num}).fetchone()
    return templates.TemplateResponse(
        request=request,
        name="post/edit.html",
        context={
            "post":row
        }
    )

# 글 수정 반영
@app.post("/post/edit/{num}")
def edit(request:Request, num:int, title:str=Form(...),content:str=Form(...),
         db:Session=Depends(get_db)):
    query=text("""
        UPDATE post
        SET title=:title, content=:content
        WHERE num=:num
               
""")
    db.execute(query,{"num":num,"title":title,"content":content})
    db.commit()
    return templates.TemplateResponse(
        request=request,
        name="post/alert.html",
        context={
            "msg":"글 정보를 수정 했습니다!",
            "url":"/post"
        }
    )