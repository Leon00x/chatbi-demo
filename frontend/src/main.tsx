import React, { useEffect, useRef, useState } from 'react'
import { createRoot } from 'react-dom/client'
import { api } from './api'
import type {ChatResult, Connection, Scenario} from './types'
import './style.css'

type Turn = {question:string;result?:ChatResult;error?:string}
function App(){
  const [scenario,setScenario]=useState<Scenario>()
  const [connection,setConnection]=useState<Connection>({state:'checking',message:'Connecting to the backend…'})
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
    const refresh=()=>api<{maas:Connection}>('/health').then(x=>{if(active)setConnection(x.maas)}).catch(()=>{if(active)setConnection({state:'backend_offline',message:'Backend is offline. Start the FastAPI service.'})})
    refresh(); const id=setInterval(refresh,5000)
    return ()=>{active=false;clearInterval(id)}
  },[])
  useEffect(()=>{bottom.current?.scrollIntoView({behavior:'smooth'})},[turns,busy])
  async function check(){setChecking(true);try{setConnection(await api<Connection>('/connection/check',{}))}catch(e){setConnection({state:'backend_offline',message:e instanceof Error?e.message:'Connection check failed.'})}finally{setChecking(false)}}
  async function send(text=question){
    if(!text.trim()||inFlight.current)return
    inFlight.current=true;setBusy(true);setQuestion('')
    const history=turns.filter(t=>t.result).slice(-6).flatMap(t=>[{role:'user',content:t.question},{role:'assistant',content:(t.result!.answer+'\n'+(t.result!.analysis || '')).slice(0,3000)}])
    setTurns(t=>[...t,{question:text}])
    try{const result=await api<ChatResult>('/chat',{question:text,analyze,history});setTurns(t=>[...t.slice(0,-1),{question:text,result}])}
    catch(e){setTurns(t=>[...t.slice(0,-1),{question:text,error:e instanceof Error?e.message:'Connection failed. Please try again.'}])}
    finally{inFlight.current=false;setBusy(false)}
  }
  return <div className="layout">
    <aside className="sidebar"><a className="brand" href="/" aria-label="ChatBI home"><img className="brand-icon" src="/merlion-v2.png" alt=""/><div>Lion City<span>RETAIL INTELLIGENCE</span></div></a>
      <button className="new-chat" disabled={busy} onClick={()=>{setTurns([]);setQuestion('');setAnalyze(false)}}>＋ New chat</button>
      <div className="nav-label">WORKSPACE</div><div className="nav-item">◈ &nbsp; Data chat <span>01</span></div>
      <div className="source-card"><div className="eyebrow">CONNECTED DATA</div><h3>{scenario?.name || 'Lion City Retail'}</h3><p>Singapore retail demo data</p><div className="source-meta">SQLite <span>● Local data</span></div><small>{scenario?.date_range.join(' → ')}</small></div>

      <div className="sidebar-footer"><span className="avatar">LC</span><div>Retail workspace<small>Powered by Huawei Cloud MaaS</small></div></div>
    </aside>
    <main><header><div><span className="header-title">ChatBI</span><span className="header-slash">/</span><span className="header-sub">Your retail data assistant</span></div><button className="connection" onClick={()=>setShowSetup(s=>!s)}><i className={connection.state==='connected'?'green':''}/>{connection.state==='connected'?'MaaS connected':'Connection settings'}</button></header>
      {(showSetup || connection.state!=='connected') && <div className="setup"><div><strong>{connection.message}</strong>{showSetup && <p>Copy backend/.env.example to .env, set MAAS_BASE_URL, MAAS_API_KEY and MAAS_MODEL, then restart the backend. Keys stay on the backend. Each connection check makes a small model request.</p>}</div><button onClick={check} disabled={checking}>{checking?'Checking…':'Check again'}</button></div>}
      <div className="conversation">
        {turns.length===0 ? <section className="welcome"><img className="welcome-mark" src="/merlion-v2.png" alt="Merlion"/><div className="eyebrow">FROM QUESTIONS TO CLARITY</div><h1>Every question opens<br/><span>your next business move.</span></h1><p>Explore stores, products and sales in plain language.<br/>Find answers in your data. Make informed decisions.</p><div className="suggestions">{(scenario?.suggestions || []).map((q,i)=><button key={q} disabled={busy} onClick={()=>send(q)}><span className="suggest-icon">{['◈','↗','▤','◎'][i]}</span><span>{q}</span><span className="arrow">↗</span></button>)}</div><div className="dataset-note">SGD · {scenario?.date_range.join(' — ')} · Synthetic demo data</div></section>:
          <div className="messages">{turns.map((turn,i)=><section className="turn" key={i}><div className="user-message">{turn.question}</div><div className="assistant-message"><img className="assistant-icon" src="/merlion-v2.png" alt=""/><div className="answer-body"><div className="answer-label">CHATBI <span>DATA ASSISTANT</span></div>{turn.error?<div role="alert" className="error">{turn.error}<button disabled={busy} onClick={()=>send(turn.question)}>Retry</button></div>:turn.result?<><p className="text-answer">{turn.result.answer}</p>{turn.result.table && <div className="table-card"><div className="table-heading">Query results <span>{turn.result.table.row_count} rows · {scenario?.currency}</span></div><div className="table-scroll"><table><thead><tr>{turn.result.table.columns.map(c=><th key={c}>{c}</th>)}</tr></thead><tbody>{turn.result.table.rows.map((row,r)=><tr key={r}>{turn.result!.table!.columns.map(c=><td key={c}>{row[c]===null?'—':typeof row[c]==='number'?new Intl.NumberFormat('en-SG',{maximumFractionDigits:2}).format(row[c] as number):String(row[c])}</td>)}</tr>)}</tbody></table></div>{!turn.result.table.rows.length && <p className="empty">No matching data</p>}</div>}{turn.result.sql && <details className="sql"><summary>View SQL</summary><pre>{turn.result.sql}</pre></details>}{turn.result.analysis && <div className="analysis"><h3>✦ Business analysis</h3><p>{turn.result.analysis}</p></div>}{turn.result.warnings.map(w=><p className="warning" key={w}>{w}</p>)}</>:<p className="loading">Understanding your question and querying the data<span>…</span></p>}</div></div></section>)}</div>}
        <div ref={bottom}/>
      </div>
      <div className="composer-wrap"><form className="composer" onSubmit={e=>{e.preventDefault();send()}}><textarea aria-label="Ask a data question" placeholder="Ask your data, e.g. Which store performed best in September 2026?" value={question} maxLength={2000} onChange={e=>setQuestion(e.target.value)} onKeyDown={e=>{if(e.key==='Enter'&&!e.shiftKey&&!e.nativeEvent.isComposing){e.preventDefault();send()}}}/><div className="composer-bottom"><label><input type="checkbox" checked={analyze} onChange={e=>setAnalyze(e.target.checked)}/> Include business analysis</label><button className="send" type="submit" disabled={busy || !question.trim()} aria-label="Send question">{busy?'…':'↑'}</button></div></form></div>
    </main>
  </div>
}
createRoot(document.getElementById('root')!).render(<React.StrictMode><App/></React.StrictMode>)
