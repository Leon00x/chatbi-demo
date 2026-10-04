import React, { useEffect, useRef, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { api } from './api'
import type {ChatResult, Connection, Scenario} from './types'
import './style.css'

type Turn = {question:string;result?:ChatResult;error?:string}
function App(){
  const [scenario,setScenario]=useState<Scenario>()
  const [connection,setConnection]=useState<Connection>({state:'checking',message:'正在连接后端…'})
  const [turns,setTurns]=useState<Turn[]>([])
  const [question,setQuestion]=useState('')
  const [analyze,setAnalyze]=useState(false)
  const [busy,setBusy]=useState(false)
  const [checking,setChecking]=useState(false)
  const [showSetup,setShowSetup]=useState(false)
  const bottom=useRef<HTMLDivElement>(null)
  const inFlight=useRef(false)
  useEffect(()=>{
    let active=true
    api<Scenario>('/scenario').then(x=>{if(active)setScenario(x)}).catch(()=>{})
    const refresh=()=>api<{maas:Connection}>('/health').then(x=>{if(active)setConnection(x.maas)}).catch(()=>{if(active)setConnection({state:'backend_offline',message:'后端未连接，请先启动 FastAPI 服务。'})})
    refresh(); const id=setInterval(refresh,5000)
    return ()=>{active=false;clearInterval(id)}
  },[])
  useEffect(()=>{bottom.current?.scrollIntoView({behavior:'smooth'})},[turns,busy])
  async function check(){setChecking(true);try{setConnection(await api<Connection>('/connection/check',{}))}catch(e){setConnection({state:'backend_offline',message:e instanceof Error?e.message:'检测失败'})}finally{setChecking(false)}}
  async function send(text=question){
    if(!text.trim()||inFlight.current)return
    inFlight.current=true;setBusy(true);setQuestion('')
    const history=turns.filter(t=>t.result).slice(-6).flatMap(t=>[{role:'user',content:t.question},{role:'assistant',content:(t.result!.answer+'\n'+(t.result!.analysis || '')).slice(0,3000)}])
    setTurns(t=>[...t,{question:text}])
    try{const result=await api<ChatResult>('/chat',{question:text,analyze,history});setTurns(t=>[...t.slice(0,-1),{question:text,result}])}
    catch(e){setTurns(t=>[...t.slice(0,-1),{question:text,error:e instanceof Error?e.message:'连接失败，请重试。'}])}
    finally{inFlight.current=false;setBusy(false)}
  }
  return <div className="layout">
    <aside className="sidebar"><a className="brand" href="/" aria-label="ChatBI 首页"><span className="brand-icon">L</span><div>Lion City<span>RETAIL INTELLIGENCE</span></div></a>
      <button className="new-chat" disabled={busy} onClick={()=>setTurns([])}>＋ 开始新对话</button>
      <div className="nav-label">工作空间</div><div className="nav-item">◈ &nbsp; 数据对话 <span>01</span></div>
      <div className="source-card"><div className="eyebrow">CONNECTED DATA</div><h3>{scenario?.name || 'Lion City Retail'}</h3><p>新加坡零售演示数据</p><div className="source-meta">SQLite <span>● 本地数据</span></div><small>{scenario?.date_range.join(' → ')}</small></div>
      <details className="metrics"><summary>业务指标口径</summary>{Object.entries(scenario?.metrics || {}).map(([k,v])=><p key={k}><b>{k}</b><br/>{v}</p>)}</details>
      <div className="sidebar-footer"><span className="avatar">LC</span><div>Retail workspace<small>Powered by Huawei Cloud MaaS</small></div></div>
    </aside>
    <main><header><div><span className="header-title">ChatBI</span><span className="header-slash">/</span><span className="header-sub">你的零售数据助手</span></div><button className="connection" onClick={()=>setShowSetup(s=>!s)}><i className={connection.state==='connected'?'green':''}/>{connection.state==='connected'?'MaaS 已连接':'配置与连接'}</button></header>
      {(showSetup || connection.state!=='connected') && <div className="setup"><div><strong>{connection.message}</strong>{showSetup && <p>将 backend/.env.example 复制为 .env，填写 MAAS_BASE_URL、MAAS_API_KEY 和 MAAS_MODEL，重启后端。密钥只保存在后端。连接检测会产生一次小额模型调用。</p>}</div><button onClick={check} disabled={checking}>{checking?'检测中…':'重新检测'}</button></div>}
      <div className="conversation">
        {turns.length===0 ? <section className="welcome"><div className="welcome-mark">✦</div><div className="eyebrow">FROM QUESTIONS TO CLARITY</div><h1>每一个问题，<br/><span>都藏着生意的下一步。</span></h1><p>用自然语言探索门店、商品与销售表现。<br/>让数据回答，让决策更有依据。</p><div className="suggestions">{(scenario?.suggestions || []).map((q,i)=><button key={q} disabled={busy} onClick={()=>send(q)}><span className="suggest-icon">{['◈','↗','▤','◎'][i]}</span><span>{q}</span><span className="arrow">↗</span></button>)}</div><div className="dataset-note">SGD · {scenario?.date_range.join(' — ')} · 合成演示数据</div></section>:
          <div className="messages">{turns.map((turn,i)=><section className="turn" key={i}><div className="user-message">{turn.question}</div><div className="assistant-message"><span className="assistant-icon">✦</span><div className="answer-body"><div className="answer-label">CHATBI <span>数据助手</span></div>{turn.error?<div role="alert" className="error">{turn.error}<button disabled={busy} onClick={()=>send(turn.question)}>重试</button></div>:turn.result?<><p className="text-answer">{turn.result.answer}</p>{turn.result.table && <div className="table-card"><div className="table-heading">查询结果 <span>{turn.result.table.row_count} 行 · {scenario?.currency}</span></div><div className="table-scroll"><table><thead><tr>{turn.result.table.columns.map(c=><th key={c}>{c}</th>)}</tr></thead><tbody>{turn.result.table.rows.map((row,r)=><tr key={r}>{turn.result!.table!.columns.map(c=><td key={c}>{row[c]===null?'—':typeof row[c]==='number'?new Intl.NumberFormat('en-SG',{maximumFractionDigits:2}).format(row[c] as number):String(row[c])}</td>)}</tr>)}</tbody></table></div>{!turn.result.table.rows.length && <p className="empty">没有匹配数据</p>}</div>}{turn.result.sql && <details className="sql"><summary>查看查询 SQL</summary><pre>{turn.result.sql}</pre></details>}{turn.result.analysis && <div className="analysis"><h3>✦ 业务分析</h3><p>{turn.result.analysis}</p></div>}{turn.result.warnings.map(w=><p className="warning" key={w}>{w}</p>)}</>:<p className="loading">正在理解问题并查询数据<span>…</span></p>}</div></div></section>)}</div>}
        <div ref={bottom}/>
      </div>
      <div className="composer-wrap"><form className="composer" onSubmit={e=>{e.preventDefault();send()}}><textarea aria-label="输入数据问题" placeholder="问问你的数据，例如：9月哪个门店表现最好？" value={question} maxLength={2000} onChange={e=>setQuestion(e.target.value)} onKeyDown={e=>{if(e.key==='Enter'&&!e.shiftKey&&!e.nativeEvent.isComposing){e.preventDefault();send()}}}/><div className="composer-bottom"><label><input type="checkbox" checked={analyze} onChange={e=>setAnalyze(e.target.checked)}/> 生成业务分析</label><button className="send" type="submit" disabled={busy || !question.trim()} aria-label="发送问题">{busy?'…':'↑'}</button></div></form><p className="footnote">模型生成 SQL，后端只读校验后执行 · 图表能力待 CodeArts Agent 扩展</p></div>
    </main>
  </div>
}
createRoot(document.getElementById('root')!).render(<React.StrictMode><App/></React.StrictMode>)
