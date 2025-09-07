# AWOC Example Usage

This document shows how to use AWOC in a real development scenario.

## Scenario: Building a FastAPI Service

### 1. Initialize AWOC in your project

```bash
# In your project directory
awoc init
```

### 2. Start a development session

```bash
awoc session start "Building FastAPI service with user authentication"
```

### 3. The api-researcher agent will help you

When you mention FastAPI or authentication, the api-researcher agent automatically activates to:

- Research FastAPI best practices
- Find authentication patterns
- Cache documentation locally
- Provide implementation examples

### 4. Development workflow

```python
# The agent helps you create clean, documented code
from fastapi import FastAPI, Depends, HTTPException
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

app = FastAPI(title="My API", version="1.0.0")

security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    # Authentication logic here
    pass

@app.get("/users/me")
async def read_users_me(current_user = Depends(get_current_user)):
    return {"user": current_user}
```

### 5. End the session

```bash
awoc session end "Completed FastAPI service with JWT authentication and user endpoints"
```

## Key Benefits

### For Individual Developers
- **Faster research**: No need to search documentation repeatedly
- **Consistent patterns**: Same approach to common problems
- **Clean commits**: Session-based development with clear boundaries
- **Learning acceleration**: Agents cache knowledge for future use

### For Teams
- **Knowledge sharing**: Agent-cached documentation available to all
- **Consistent standards**: Same patterns across team members
- **Faster onboarding**: New developers get up to speed quickly
- **Reduced duplication**: Common solutions documented once, reused many times

## Advanced Usage

### Custom Agents (Future)
```bash
# Will support custom agents for specific domains
awoc agent create "data-scientist" --tools pandas,numpy,matplotlib
```

### Multi-agent Sessions (Future)
```bash
# Coordinate multiple agents
awoc session start --agents api-researcher,code-architect "Full-stack feature development"
```

### Plugin System (Future)
```bash
# Extend with community plugins
awoc plugin install "react-developer"
awoc plugin install "database-expert"
```