export async function api<T>(path:string, body?:unknown):Promise<T> {
  const response = await fetch('/api'+path, {method:body === undefined?'GET':'POST', headers:body === undefined?{}:{'Content-Type':'application/json'}, body:body === undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(150000)})
  const data = await response.json()
  if(!response.ok) throw new Error(typeof data.detail === 'string'?data.detail:data.detail?.message || '请求失败，请检查服务状态。')
  return data
}
