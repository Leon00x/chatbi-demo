import httpx
from . import config

class MaaSError(Exception):
    def __init__(self, code: str, message: str):
        self.code, self.message = code, message
        super().__init__(message)

def configuration_error():
    if not config.API_KEY.strip():
        return ('missing_key', '尚未配置 MAAS_API_KEY，请填写 backend/.env 并重启后端。')
    if not config.BASE_URL.startswith('https://') or not config.MODEL:
        return ('invalid_config', '请配置 HTTPS MAAS_BASE_URL 和 MAAS_MODEL，并重启后端。')
    return None

async def completion(messages, max_tokens=1200):
    error = configuration_error()
    if error:
        raise MaaSError(*error)
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(60, connect=10), follow_redirects=False) as client:
            response = await client.post(config.BASE_URL + '/chat/completions', headers={'Authorization': 'Bearer ' + config.API_KEY}, json={'model': config.MODEL, 'messages': messages, 'temperature': 0, 'max_tokens': max_tokens, 'stream': False})
        if response.status_code in (401,403):
            raise MaaSError('auth_failed', '鉴权失败：请检查 key 是否有效及模型访问权限。')
        if response.status_code == 404:
            raise MaaSError('model_or_endpoint', '端点或模型不存在，请检查 BASE_URL 与 MODEL。')
        if response.status_code == 429:
            raise MaaSError('rate_limited', 'MaaS 限流或配额不足，请稍后重试或检查配额。')
        if not response.is_success:
            raise MaaSError('upstream_error', f'MaaS 返回 HTTP {response.status_code}，请检查服务状态。')
        content = response.json()['choices'][0]['message']['content']
        if not isinstance(content, str) or not content.strip():
            raise ValueError()
        return content
    except httpx.TimeoutException:
        raise MaaSError('timeout', 'MaaS 请求超时，请检查网络或稍后重试。') from None
    except httpx.RequestError:
        raise MaaSError('network_error', '无法连接 MaaS，请检查端点、DNS 和网络。') from None
    except (KeyError, IndexError, ValueError, TypeError):
        raise MaaSError('invalid_response', 'MaaS 返回格式异常。') from None

async def check_connection():
    try:
        await completion([{'role':'user','content':'Reply with OK.'}], max_tokens=32)
        return {'state':'connected','message':'MaaS 实际调用成功，模型与 key 可用。'}
    except MaaSError as error:
        return {'state':error.code,'message':error.message}
