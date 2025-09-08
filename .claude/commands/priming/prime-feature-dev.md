# Feature Development Context Primer
*Token Budget: 3000 | Focus: Design, Implementation, Testing*

## Development Methodology
### Feature Development Lifecycle
1. **Requirements Analysis** - Understand what needs to be built
2. **Design Phase** - Architecture and component planning
3. **Implementation** - Code the feature incrementally
4. **Testing** - Unit, integration, and user acceptance
5. **Integration** - Merge with existing codebase
6. **Documentation** - Update guides and API docs

### Incremental Development Pattern
```bash
# Start small, build iteratively
1. Create minimal viable implementation
2. Add one capability at a time
3. Test each increment thoroughly
4. Refactor when needed
5. Expand to full feature set
```

## Design Patterns & Architecture
### Common Development Patterns
```python
# Single Responsibility Principle
class UserValidator:
    def validate_email(self, email: str) -> bool:
        return "@" in email and "." in email
    
class UserRepository:
    def save_user(self, user: User) -> bool:
        return database.insert(user)

# Dependency Injection
class UserService:
    def __init__(self, validator: UserValidator, repo: UserRepository):
        self.validator = validator
        self.repo = repo
```

### API Design Principles
```python
# RESTful API patterns
GET    /api/users          # List users
GET    /api/users/{id}     # Get specific user
POST   /api/users          # Create user
PUT    /api/users/{id}     # Update user
DELETE /api/users/{id}     # Delete user

# Response patterns
{
    "success": true,
    "data": {...},
    "message": "Operation completed",
    "timestamp": "2024-01-01T00:00:00Z"
}
```

## Implementation Best Practices
### Code Structure
```bash
# Feature-based organization
src/
├── features/
│   ├── user_management/
│   │   ├── models.py
│   │   ├── services.py
│   │   ├── controllers.py
│   │   └── tests/
│   └── authentication/
│       ├── auth_service.py
│       ├── middleware.py
│       └── tests/
```

### Error Handling Patterns
```python
# Robust error handling
from typing import Optional, Union

class Result:
    def __init__(self, success: bool, data: any = None, error: str = None):
        self.success = success
        self.data = data
        self.error = error

def create_user(user_data: dict) -> Result:
    try:
        # Validate input
        if not user_data.get('email'):
            return Result(False, error="Email is required")
        
        # Process
        user = User(user_data)
        saved = repository.save(user)
        
        return Result(True, data=saved)
    except Exception as e:
        return Result(False, error=f"Failed to create user: {str(e)}")
```

## Testing Strategy
### Test-Driven Development
```python
# Write tests first, then implementation
def test_user_creation():
    """Test user creation with valid data"""
    user_data = {"email": "test@example.com", "name": "Test User"}
    result = create_user(user_data)
    
    assert result.success is True
    assert result.data.email == "test@example.com"

def test_user_creation_invalid_email():
    """Test user creation fails with invalid email"""
    user_data = {"email": "invalid", "name": "Test User"}
    result = create_user(user_data)
    
    assert result.success is False
    assert "email" in result.error.lower()
```

### Testing Layers
```bash
# Unit Tests - Individual functions/methods
pytest tests/unit/

# Integration Tests - Component interactions
pytest tests/integration/

# End-to-End Tests - Full workflow
pytest tests/e2e/

# Performance Tests - Load and stress
pytest tests/performance/
```

## Configuration Management
### Environment-Based Config
```python
# config.py
import os
from typing import Dict

class Config:
    def __init__(self):
        self.database_url = os.getenv('DATABASE_URL', 'sqlite:///default.db')
        self.api_key = os.getenv('API_KEY', '')
        self.debug = os.getenv('DEBUG', 'False').lower() == 'true'
    
    def validate(self) -> bool:
        """Validate required configuration"""
        return bool(self.database_url and self.api_key)

# Feature-specific config
class FeatureFlags:
    ENABLE_NEW_FEATURE = os.getenv('ENABLE_NEW_FEATURE', 'false').lower() == 'true'
    BETA_USERS_ONLY = os.getenv('BETA_USERS_ONLY', 'true').lower() == 'true'
```

### Docker Configuration
```dockerfile
# Multi-stage build for features
FROM python:3.11-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN uv sync

FROM python:3.11-slim as runtime
WORKDIR /app
COPY --from=builder /app/.venv /app/.venv
COPY src/ ./src/
ENV PATH="/app/.venv/bin:$PATH"
CMD ["python", "src/main.py"]
```

## Database Integration
### Migration Patterns
```python
# Database migrations
def upgrade():
    """Add new feature table"""
    op.create_table('feature_data',
        sa.Column('id', sa.Integer, primary_key=True),
        sa.Column('name', sa.String(100), nullable=False),
        sa.Column('config', sa.JSON),
        sa.Column('created_at', sa.DateTime, default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime, onupdate=sa.func.now())
    )

def downgrade():
    """Remove feature table if needed"""
    op.drop_table('feature_data')
```

### Query Optimization
```python
# Efficient database queries
class UserRepository:
    def find_active_users(self, limit: int = 100) -> List[User]:
        return self.session.query(User)\
            .filter(User.active == True)\
            .order_by(User.created_at.desc())\
            .limit(limit)\
            .all()
    
    def find_with_relations(self, user_id: int) -> Optional[User]:
        return self.session.query(User)\
            .options(joinedload(User.profile))\
            .filter(User.id == user_id)\
            .first()
```

## Performance Considerations
### Async Programming
```python
import asyncio
from aiohttp import web

async def handle_user_creation(request):
    """Async request handler"""
    data = await request.json()
    
    # Parallel processing
    validation_task = asyncio.create_task(validate_user_data(data))
    duplication_check = asyncio.create_task(check_duplicate_user(data['email']))
    
    # Wait for both
    is_valid, is_duplicate = await asyncio.gather(validation_task, duplication_check)
    
    if not is_valid or is_duplicate:
        return web.json_response({"error": "Invalid user data"}, status=400)
    
    user = await create_user_async(data)
    return web.json_response({"user": user.to_dict()})
```

### Caching Strategy
```python
from functools import lru_cache
import redis

# Memory caching
@lru_cache(maxsize=1000)
def expensive_computation(param: str) -> str:
    """Cache computation results"""
    return complex_algorithm(param)

# Redis caching
class CacheService:
    def __init__(self, redis_client):
        self.redis = redis_client
    
    async def get_or_compute(self, key: str, compute_fn, ttl: int = 3600):
        cached = await self.redis.get(key)
        if cached:
            return json.loads(cached)
        
        result = await compute_fn()
        await self.redis.setex(key, ttl, json.dumps(result))
        return result
```

## Monitoring & Observability
### Logging Patterns
```python
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

def create_user_with_logging(user_data: Dict[str, Any]) -> Result:
    """Create user with comprehensive logging"""
    logger.info("Starting user creation", extra={
        "operation": "create_user",
        "email": user_data.get("email", "unknown")
    })
    
    try:
        result = create_user(user_data)
        if result.success:
            logger.info("User created successfully", extra={
                "user_id": result.data.id,
                "operation": "create_user"
            })
        else:
            logger.warning("User creation failed", extra={
                "error": result.error,
                "operation": "create_user"
            })
        return result
    except Exception as e:
        logger.error("User creation error", extra={
            "error": str(e),
            "operation": "create_user"
        }, exc_info=True)
        raise
```

### Metrics Collection
```python
from prometheus_client import Counter, Histogram
import time

# Define metrics
user_creation_counter = Counter('users_created_total', 'Total users created')
user_creation_duration = Histogram('user_creation_duration_seconds', 'Time to create user')

def create_user_with_metrics(user_data: Dict[str, Any]) -> Result:
    """Create user with metrics tracking"""
    start_time = time.time()
    
    try:
        result = create_user(user_data)
        if result.success:
            user_creation_counter.inc()
        return result
    finally:
        user_creation_duration.observe(time.time() - start_time)
```

## Documentation Templates
### API Documentation
```markdown
## POST /api/users

Create a new user account.

### Request Body
```json
{
  "email": "user@example.com",
  "name": "John Doe",
  "role": "user"
}
```

### Response
```json
{
  "success": true,
  "data": {
    "id": 123,
    "email": "user@example.com",
    "name": "John Doe",
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### Error Responses
- `400 Bad Request` - Invalid input data
- `409 Conflict` - Email already exists
- `500 Internal Server Error` - Server error
```

## Git Workflow for Features
### Feature Branch Strategy
```bash
# Create feature branch
git checkout -b feature/user-management

# Regular commits during development
git add -A
git commit -m "feat: add user creation endpoint

- Implement POST /api/users
- Add user validation
- Include comprehensive tests
- Add API documentation"

# Push and create PR
git push -u origin feature/user-management
```

---
**Priming Active**: Feature development patterns and best practices loaded. Ready for building robust, well-tested features with proper architecture.