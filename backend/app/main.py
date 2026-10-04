import asyncio
import sqlite3
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import Literal
from sqlglot.errors import SqlglotError
from .config import SCENARIO, MODEL, CORS_ORIGINS
from .database import seed_database
from .maas import check_connection, MaaSError, configuration_error
from .service import chat

status = {'state':'checking','message':'正在检测 MaaS 连接…'}

@asynccontextmanager
async def lifespan(app):
    global status
    seed_database()
    error = configuration_error()
    if error:
        status = {'state':error[0], 'message':error[1]}
        task = None
    else:
        async def probe():
            global status
            status = await check_connection()
        task = asyncio.create_task(probe())
    yield
    if task and not task.done():
        task.cancel()

app = FastAPI(title='ChatBI Retail Demo', lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=CORS_ORIGINS, allow_methods=['GET','POST'], allow_headers=['Content-Type'])

class Message(BaseModel):
    role: Literal['user','assistant']
    content: str = Field(max_length=3000)

class ChatRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)
    history: list[Message] = Field(default_factory=list, max_length=12)
    analyze: bool = False

@app.get('/api/health')
def health():
    return {'status':'ok', 'maas':status, 'model':MODEL, 'database':'sqlite', 'features':{'charts':False}}

@app.post('/api/connection/check')
async def connection_check():
    global status
    status = await check_connection()
    return status

@app.get('/api/scenario')
def scenario():
    return {k:SCENARIO[k] for k in ['id','name','subtitle','description','currency','date_range','suggestions','metrics']}

@app.post('/api/chat')
async def chat_endpoint(request: ChatRequest):
    if not request.question.strip():
        raise HTTPException(422, '问题不能为空')
    try:
        return await chat(request.question, [m.model_dump() for m in request.history], request.analyze)
    except MaaSError as error:
        raise HTTPException(503, {'code':error.code,'message':error.message}) from None
    except (ValueError, sqlite3.Error, SqlglotError):
        raise HTTPException(422, {'code':'invalid_query','message':'无法安全执行该查询，请明确日期、指标和维度后重试。'}) from None
