# API Integration Context Primer
*Token Budget: 3000 | Focus: Integration, Authentication, Error Handling*

## API Integration Methodology
### Integration Development Lifecycle
1. **API Discovery** - Explore endpoints and capabilities
2. **Authentication Setup** - Configure API keys and auth flow
3. **Request/Response Mapping** - Understand data structures
4. **Error Handling** - Handle all failure scenarios
5. **Rate Limiting** - Implement proper throttling
6. **Testing** - Comprehensive integration testing
7. **Monitoring** - Track usage and performance

### Integration Patterns
```python
# Base API client pattern
import requests
from typing import Dict, Any, Optional
import time
from datetime import datetime, timedelta

class APIClient:
    def __init__(self, base_url: str, api_key: str, timeout: int = 30):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {api_key}',
            'Content-Type': 'application/json',
            'User-Agent': 'AWOC-Integration/1.0'
        })
    
    def _make_request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        url = f"{self.base_url}/{endpoint.lstrip('/')}"
        response = self.session.request(method, url, timeout=self.timeout, **kwargs)
        response.raise_for_status()
        return response
```

## Authentication Strategies
### API Key Authentication
```python
class APIKeyAuth:
    def __init__(self, api_key: str, key_location: str = 'header'):
        self.api_key = api_key
        self.key_location = key_location
    
    def apply_auth(self, headers: Dict[str, str], params: Dict[str, str]) -> tuple:
        if self.key_location == 'header':
            headers['Authorization'] = f'Bearer {self.api_key}'
        elif self.key_location == 'query':
            params['api_key'] = self.api_key
        elif self.key_location == 'header_custom':
            headers['X-API-Key'] = self.api_key
        return headers, params
```

### OAuth 2.0 Flow
```python
import base64
from urllib.parse import urlencode

class OAuth2Client:
    def __init__(self, client_id: str, client_secret: str, auth_url: str, token_url: str):
        self.client_id = client_id
        self.client_secret = client_secret
        self.auth_url = auth_url
        self.token_url = token_url
        self.access_token = None
        self.refresh_token = None
        self.token_expires_at = None
    
    def get_authorization_url(self, redirect_uri: str, scope: str = None) -> str:
        params = {
            'client_id': self.client_id,
            'response_type': 'code',
            'redirect_uri': redirect_uri,
        }
        if scope:
            params['scope'] = scope
        
        return f"{self.auth_url}?{urlencode(params)}"
    
    def exchange_code_for_token(self, code: str, redirect_uri: str) -> Dict[str, Any]:
        auth_header = base64.b64encode(f"{self.client_id}:{self.client_secret}".encode()).decode()
        
        headers = {
            'Authorization': f'Basic {auth_header}',
            'Content-Type': 'application/x-www-form-urlencoded'
        }
        
        data = {
            'grant_type': 'authorization_code',
            'code': code,
            'redirect_uri': redirect_uri
        }
        
        response = requests.post(self.token_url, headers=headers, data=data)
        token_data = response.json()
        
        self.access_token = token_data['access_token']
        if 'refresh_token' in token_data:
            self.refresh_token = token_data['refresh_token']
        
        # Calculate expiration time
        if 'expires_in' in token_data:
            self.token_expires_at = datetime.now() + timedelta(seconds=token_data['expires_in'])
        
        return token_data
```

## Request/Response Handling
### Data Transformation
```python
from typing import TypeVar, Generic, List
from dataclasses import dataclass
from datetime import datetime
import json

T = TypeVar('T')

@dataclass
class APIResponse(Generic[T]):
    success: bool
    data: T
    message: str = ""
    status_code: int = 200
    headers: Dict[str, str] = None

class DataMapper:
    @staticmethod
    def map_user_from_api(api_data: Dict[str, Any]) -> 'User':
        return User(
            id=api_data.get('id'),
            email=api_data.get('email'),
            name=api_data.get('full_name', api_data.get('name')),
            created_at=datetime.fromisoformat(api_data.get('created_at', '').replace('Z', '+00:00'))
        )
    
    @staticmethod
    def map_user_to_api(user: 'User') -> Dict[str, Any]:
        return {
            'email': user.email,
            'full_name': user.name,
            'metadata': user.metadata or {}
        }
```

### Pagination Handling
```python
class PaginatedAPI:
    def __init__(self, client: APIClient):
        self.client = client
    
    def get_all_items(self, endpoint: str, page_param: str = 'page', 
                     limit_param: str = 'limit', limit: int = 100) -> List[Dict[str, Any]]:
        """Fetch all items from a paginated API"""
        all_items = []
        page = 1
        
        while True:
            params = {page_param: page, limit_param: limit}
            response = self.client._make_request('GET', endpoint, params=params)
            data = response.json()
            
            # Handle different pagination response formats
            if 'data' in data:
                items = data['data']
                has_more = data.get('has_more', False)
            elif 'results' in data:
                items = data['results']
                has_more = data.get('next') is not None
            else:
                items = data
                has_more = len(items) == limit
            
            all_items.extend(items)
            
            if not has_more or len(items) < limit:
                break
                
            page += 1
            time.sleep(0.1)  # Rate limiting
        
        return all_items
```

## Error Handling & Resilience
### Comprehensive Error Handling
```python
import logging
from enum import Enum
from typing import Optional

class APIError(Exception):
    def __init__(self, message: str, status_code: int = None, response: str = None):
        self.message = message
        self.status_code = status_code
        self.response = response
        super().__init__(self.message)

class ErrorType(Enum):
    NETWORK = "network"
    AUTHENTICATION = "authentication"
    AUTHORIZATION = "authorization"
    RATE_LIMIT = "rate_limit"
    VALIDATION = "validation"
    SERVER = "server"
    CLIENT = "client"

class ResilientAPIClient:
    def __init__(self, client: APIClient, max_retries: int = 3, backoff_factor: float = 1.0):
        self.client = client
        self.max_retries = max_retries
        self.backoff_factor = backoff_factor
        self.logger = logging.getLogger(__name__)
    
    def make_request_with_retry(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        last_exception = None
        
        for attempt in range(self.max_retries + 1):
            try:
                response = self.client._make_request(method, endpoint, **kwargs)
                return response
            
            except requests.exceptions.HTTPError as e:
                status_code = e.response.status_code if e.response else None
                
                if status_code == 429:  # Rate limit
                    retry_after = int(e.response.headers.get('Retry-After', 60))
                    self.logger.warning(f"Rate limited, waiting {retry_after} seconds")
                    time.sleep(retry_after)
                    continue
                elif 500 <= status_code < 600:  # Server errors
                    if attempt < self.max_retries:
                        wait_time = self.backoff_factor * (2 ** attempt)
                        self.logger.warning(f"Server error {status_code}, retrying in {wait_time}s")
                        time.sleep(wait_time)
                        continue
                
                last_exception = e
                break
            
            except (requests.exceptions.ConnectionError, requests.exceptions.Timeout) as e:
                if attempt < self.max_retries:
                    wait_time = self.backoff_factor * (2 ** attempt)
                    self.logger.warning(f"Network error, retrying in {wait_time}s: {e}")
                    time.sleep(wait_time)
                    continue
                last_exception = e
                break
        
        raise APIError(f"Request failed after {self.max_retries + 1} attempts") from last_exception
```

## Rate Limiting & Throttling
### Rate Limiter Implementation
```python
import asyncio
from collections import defaultdict, deque
from typing import Dict

class RateLimiter:
    def __init__(self, max_requests: int, time_window: int):
        self.max_requests = max_requests
        self.time_window = time_window
        self.requests: Dict[str, deque] = defaultdict(deque)
    
    def can_make_request(self, identifier: str = "default") -> bool:
        now = time.time()
        request_times = self.requests[identifier]
        
        # Remove old requests outside the time window
        while request_times and request_times[0] <= now - self.time_window:
            request_times.popleft()
        
        return len(request_times) < self.max_requests
    
    def add_request(self, identifier: str = "default"):
        now = time.time()
        self.requests[identifier].append(now)
    
    def wait_time(self, identifier: str = "default") -> float:
        if self.can_make_request(identifier):
            return 0
        
        now = time.time()
        oldest_request = self.requests[identifier][0]
        return max(0, self.time_window - (now - oldest_request))

class ThrottledAPIClient:
    def __init__(self, client: APIClient, rate_limiter: RateLimiter):
        self.client = client
        self.rate_limiter = rate_limiter
    
    def make_request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        # Wait if necessary
        wait_time = self.rate_limiter.wait_time()
        if wait_time > 0:
            time.sleep(wait_time)
        
        # Make the request
        response = self.client._make_request(method, endpoint, **kwargs)
        self.rate_limiter.add_request()
        
        return response
```

## Testing Strategies
### Mock API Testing
```python
import responses
from unittest.mock import patch, Mock

class TestAPIIntegration:
    @responses.activate
    def test_successful_api_call(self):
        # Mock the API response
        responses.add(
            responses.GET,
            'https://api.example.com/users/123',
            json={'id': 123, 'name': 'John Doe', 'email': 'john@example.com'},
            status=200
        )
        
        client = APIClient('https://api.example.com', 'test-key')
        response = client._make_request('GET', '/users/123')
        
        assert response.status_code == 200
        data = response.json()
        assert data['name'] == 'John Doe'
    
    @responses.activate
    def test_api_error_handling(self):
        responses.add(
            responses.GET,
            'https://api.example.com/users/999',
            json={'error': 'User not found'},
            status=404
        )
        
        client = APIClient('https://api.example.com', 'test-key')
        
        with pytest.raises(requests.exceptions.HTTPError):
            client._make_request('GET', '/users/999')
```

### Integration Test Scenarios
```python
def test_end_to_end_integration():
    """Test complete integration workflow"""
    # 1. Authentication
    client = APIClient(base_url, api_key)
    
    # 2. Create resource
    create_data = {"name": "Test Resource", "type": "test"}
    create_response = client._make_request('POST', '/resources', json=create_data)
    resource_id = create_response.json()['id']
    
    # 3. Retrieve resource
    get_response = client._make_request('GET', f'/resources/{resource_id}')
    retrieved_data = get_response.json()
    
    # 4. Verify data consistency
    assert retrieved_data['name'] == create_data['name']
    assert retrieved_data['type'] == create_data['type']
    
    # 5. Update resource
    update_data = {"name": "Updated Resource"}
    update_response = client._make_request('PUT', f'/resources/{resource_id}', json=update_data)
    
    # 6. Verify update
    final_response = client._make_request('GET', f'/resources/{resource_id}')
    final_data = final_response.json()
    assert final_data['name'] == update_data['name']
    
    # 7. Cleanup
    delete_response = client._make_request('DELETE', f'/resources/{resource_id}')
    assert delete_response.status_code == 204
```

## Documentation & Monitoring
### API Usage Documentation
```python
class APIDocumentationGenerator:
    def __init__(self, client: APIClient):
        self.client = client
        self.endpoints = []
    
    def document_endpoint(self, method: str, endpoint: str, description: str, 
                         example_request: Dict = None, example_response: Dict = None):
        self.endpoints.append({
            'method': method,
            'endpoint': endpoint,
            'description': description,
            'example_request': example_request,
            'example_response': example_response
        })
    
    def generate_markdown(self) -> str:
        md = "# API Integration Documentation\n\n"
        
        for endpoint in self.endpoints:
            md += f"## {endpoint['method']} {endpoint['endpoint']}\n\n"
            md += f"{endpoint['description']}\n\n"
            
            if endpoint['example_request']:
                md += "### Request Example\n"
                md += f"```json\n{json.dumps(endpoint['example_request'], indent=2)}\n```\n\n"
            
            if endpoint['example_response']:
                md += "### Response Example\n"
                md += f"```json\n{json.dumps(endpoint['example_response'], indent=2)}\n```\n\n"
        
        return md
```

### Monitoring & Metrics
```python
class APIMetrics:
    def __init__(self):
        self.request_count = 0
        self.error_count = 0
        self.response_times = []
        self.status_codes = defaultdict(int)
    
    def record_request(self, response_time: float, status_code: int):
        self.request_count += 1
        self.response_times.append(response_time)
        self.status_codes[status_code] += 1
        
        if status_code >= 400:
            self.error_count += 1
    
    def get_stats(self) -> Dict[str, Any]:
        return {
            'total_requests': self.request_count,
            'error_count': self.error_count,
            'error_rate': self.error_count / self.request_count if self.request_count > 0 else 0,
            'avg_response_time': statistics.mean(self.response_times) if self.response_times else 0,
            'status_code_distribution': dict(self.status_codes)
        }
```

## Common API Patterns
### REST API Client Template
```bash
# Generic REST client generation script
#!/bin/bash

API_NAME="$1"
BASE_URL="$2"
API_KEY="$3"

cat > "${API_NAME}_client.py" << EOF
"""
${API_NAME} API Client
Generated on $(date)
"""

import requests
from typing import Dict, Any, List, Optional
from dataclasses import dataclass

@dataclass
class ${API_NAME}Client:
    base_url: str = "${BASE_URL}"
    api_key: str = "${API_KEY}"
    timeout: int = 30
    
    def __post_init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            'Authorization': f'Bearer {self.api_key}',
            'Content-Type': 'application/json'
        })
    
    def get(self, endpoint: str, params: Dict = None) -> Dict[str, Any]:
        response = self.session.get(
            f"{self.base_url}/{endpoint.lstrip('/')}",
            params=params,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()
    
    def post(self, endpoint: str, data: Dict = None) -> Dict[str, Any]:
        response = self.session.post(
            f"{self.base_url}/{endpoint.lstrip('/')}",
            json=data,
            timeout=self.timeout
        )
        response.raise_for_status()
        return response.json()
EOF

echo "Generated ${API_NAME}_client.py"
```

---
**Priming Active**: API integration patterns and best practices loaded. Ready for robust API integration with authentication, error handling, rate limiting, and comprehensive testing capabilities.