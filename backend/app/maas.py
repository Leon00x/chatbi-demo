import httpx
from . import config

class MaaSError(Exception):
    def __init__(self, code: str, message: str):
        self.code, self.message = code, message
        super().__init__(message)

def configuration_error():
    if not config.API_KEY.strip():
        return ('missing_key', 'No MaaS key configured. Set it in backend/.env and restart the backend.')
    if not config.BASE_URL.startswith('https://') or not config.MODEL:
        return ('invalid_config', 'Set an HTTPS MaaS base URL and model in backend/.env, then restart the backend.')
    return None

async def completion(messages, max_tokens=1200):
    error = configuration_error()
    if error:
        raise MaaSError(*error)
    try:
        async with httpx.AsyncClient(timeout=httpx.Timeout(60, connect=10), follow_redirects=False) as client:
            response = await client.post(config.BASE_URL + '/chat/completions', headers={'Authorization': 'Bearer ' + config.API_KEY}, json={'model': config.MODEL, 'messages': messages, 'temperature': 0, 'max_tokens': max_tokens, 'stream': False})
        if response.status_code in (401,403):
            raise MaaSError('auth_failed', 'Authentication failed. Check your key and model permissions.')
        if response.status_code == 404:
            raise MaaSError('model_or_endpoint', 'Endpoint or model not found. Check the base URL and model.')
        if response.status_code == 429:
            raise MaaSError('rate_limited', 'MaaS rate limit or quota exceeded. Try again later or check your quota.')
        if not response.is_success:
            raise MaaSError('upstream_error', f'MaaS returned HTTP {response.status_code}. Check the service status.')
        content = response.json()['choices'][0]['message']['content']
        if not isinstance(content, str) or not content.strip():
            raise ValueError()
        return content
    except httpx.TimeoutException:
        raise MaaSError('timeout', 'MaaS request timed out. Check your network or try again later.') from None
    except httpx.RequestError:
        raise MaaSError('network_error', 'Unable to connect to MaaS. Check the endpoint, DNS and network.') from None
    except (KeyError, IndexError, ValueError, TypeError):
        raise MaaSError('invalid_response', 'MaaS returned an invalid response.') from None

async def check_connection():
    try:
        await completion([{'role':'user','content':'Reply with OK.'}], max_tokens=32)
        return {'state':'connected','message':'MaaS connection verified. The model and key are working.'}
    except MaaSError as error:
        return {'state':error.code,'message':error.message}
