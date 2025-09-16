# Research Context Primer
*Token Budget: 3000 | Focus: Investigation, Analysis, Discovery*

## Research Methodology
### Systematic Investigation Approach
1. **Define Question** - What exactly needs to be discovered?
2. **Identify Sources** - Documentation, code, APIs, community
3. **Gather Evidence** - Collect relevant information
4. **Analyze Patterns** - Find connections and insights
5. **Synthesize Findings** - Create actionable conclusions
6. **Document Results** - Record for future reference

### Research Question Types
```markdown
# Technical Questions
- How does X work internally?
- What are the performance characteristics of Y?
- How do A and B integrate?
- What are the trade-offs between options?

# Implementation Questions
- What's the best approach for Z?
- How do others solve this problem?
- What tools/libraries are available?
- What are common pitfalls to avoid?

# Decision Questions
- Which option fits our constraints?
- What are the long-term implications?
- How does this align with goals?
- What's the cost-benefit analysis?
```

## Information Sources & Tools
### Documentation Research
```bash
# Official documentation
curl -s "https://api.github.com/repos/owner/repo" | jq '.description'
curl -s "https://api.github.com/repos/owner/repo/readme" | jq -r '.content' | base64 -d

# Package information
npm info package-name
pip show package-name
uv tree package-name

# Manual pages and help
man command
command --help
command -h
info command
```

### Code Analysis Tools
```bash
# Repository exploration
find . -name "*.py" | head -20
find . -type f -exec grep -l "search_term" {} \;
git log --oneline --grep="keyword"
git log --follow --patch -- filename

# Dependency analysis
ldd binary_file
objdump -T library.so
nm -D library.so
lsof -p process_id

# Code statistics
cloc --by-file .
wc -l **/*.py
grep -r "TODO\|FIXME\|HACK" .
```

### API Research Patterns
```python
# API exploration script template
import requests
import json
from typing import Dict, Any

def explore_api_endpoint(base_url: str, endpoint: str, headers: Dict[str, str] = None) -> Dict[str, Any]:
    """Research API endpoint capabilities"""
    url = f"{base_url.rstrip('/')}/{endpoint.lstrip('/')}"
    
    try:
        # Try different HTTP methods
        methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS']
        results = {}
        
        for method in methods:
            try:
                response = requests.request(method, url, headers=headers, timeout=10)
                results[method] = {
                    'status_code': response.status_code,
                    'headers': dict(response.headers),
                    'body': response.text[:1000] if response.text else None
                }
            except Exception as e:
                results[method] = {'error': str(e)}
        
        return results
    except Exception as e:
        return {'error': f"Failed to explore endpoint: {e}"}

# Usage
results = explore_api_endpoint("https://api.example.com", "/users")
print(json.dumps(results, indent=2))
```

## Analysis Techniques
### Pattern Recognition
```bash
# Log pattern analysis
grep -E "(ERROR|WARN)" logs/* | cut -d: -f3 | sort | uniq -c | sort -nr
awk '{print $4}' access.log | sort | uniq -c | sort -nr

# Configuration pattern analysis
find . -name "*.json" -exec jq keys {} \; | sort | uniq
find . -name "*.yaml" -exec yq e 'keys' {} \; | sort | uniq

# Code pattern analysis
grep -r "class.*:" --include="*.py" | wc -l
grep -r "def.*:" --include="*.py" | wc -l
grep -r "import.*" --include="*.py" | cut -d: -f2 | sort | uniq -c | sort -nr
```

### Performance Analysis
```python
# Benchmark comparison template
import time
import statistics
from typing import List, Callable

def benchmark_function(func: Callable, iterations: int = 1000, *args, **kwargs) -> Dict[str, float]:
    """Benchmark a function's performance"""
    times = []
    
    for _ in range(iterations):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        end = time.perf_counter()
        times.append(end - start)
    
    return {
        'mean': statistics.mean(times),
        'median': statistics.median(times),
        'stdev': statistics.stdev(times) if len(times) > 1 else 0,
        'min': min(times),
        'max': max(times),
        'total_time': sum(times),
        'iterations': iterations
    }

# Memory usage analysis
import tracemalloc

def memory_profile(func: Callable, *args, **kwargs):
    """Profile memory usage of a function"""
    tracemalloc.start()
    
    result = func(*args, **kwargs)
    
    current, peak = tracemalloc.get_traced_memory()
    tracemalloc.stop()
    
    return {
        'result': result,
        'current_memory': current,
        'peak_memory': peak,
        'current_mb': current / 1024 / 1024,
        'peak_mb': peak / 1024 / 1024
    }
```

## Technology Evaluation Framework
### Evaluation Criteria Matrix
```markdown
## Technology Comparison Template

### Option A: [Technology Name]
**Pros:**
- Performance characteristics
- Community support
- Documentation quality
- Integration ease
- Learning curve

**Cons:**
- Limitations
- Known issues
- Maintenance overhead
- Compatibility concerns

**Metrics:**
- GitHub stars: X
- Last commit: Date
- Issues open/closed: X/Y
- Contributors: N
- License: Type

### Decision Matrix
| Criteria | Weight | Option A | Option B | Option C |
|----------|--------|----------|----------|----------|
| Performance | 0.3 | 8 | 6 | 9 |
| Maintenance | 0.2 | 7 | 9 | 5 |
| Community | 0.2 | 9 | 8 | 6 |
| Integration | 0.3 | 6 | 7 | 8 |
| **Total** | 1.0 | 7.3 | 7.2 | 7.4 |
```

### Technology Stack Research
```python
# Ecosystem analysis tool
import subprocess
import json
from typing import Dict, List

def analyze_package_ecosystem(package_manager: str, package_name: str) -> Dict[str, Any]:
    """Analyze package ecosystem information"""
    
    if package_manager == "npm":
        cmd = ["npm", "info", package_name, "--json"]
    elif package_manager == "pip":
        cmd = ["pip", "show", package_name, "--verbose"]
    elif package_manager == "uv":
        cmd = ["uv", "show", package_name]
    else:
        return {"error": "Unsupported package manager"}
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return {"output": result.stdout, "success": True}
        else:
            return {"error": result.stderr, "success": False}
    except subprocess.TimeoutExpired:
        return {"error": "Command timed out", "success": False}
    except Exception as e:
        return {"error": str(e), "success": False}
```

## Data Collection & Analysis
### Web Scraping Research
```python
# Research web scraping template
import requests
from bs4 import BeautifulSoup
import time
from typing import List, Dict

def scrape_documentation_links(base_url: str, max_pages: int = 10) -> List[Dict[str, str]]:
    """Scrape documentation links from a website"""
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Research Bot 1.0 (Educational Purpose)'
    })
    
    links = []
    visited = set()
    to_visit = [base_url]
    
    while to_visit and len(links) < max_pages:
        url = to_visit.pop(0)
        if url in visited:
            continue
        
        try:
            response = session.get(url, timeout=10)
            if response.status_code == 200:
                soup = BeautifulSoup(response.content, 'html.parser')
                
                # Extract relevant links
                for link in soup.find_all('a', href=True):
                    href = link['href']
                    text = link.get_text().strip()
                    
                    if 'doc' in href.lower() or 'guide' in href.lower():
                        links.append({
                            'url': href,
                            'text': text,
                            'source_page': url
                        })
                
                visited.add(url)
                time.sleep(1)  # Be respectful
                
        except Exception as e:
            print(f"Error scraping {url}: {e}")
    
    return links
```

### Survey & Community Research
```bash
# GitHub research commands
gh repo list --topic "machine-learning" --limit 50 --json name,url,stargazerCount
gh issue list --repo owner/repo --state open --json title,url,createdAt
gh pr list --repo owner/repo --state merged --json title,url,mergedAt

# Community activity analysis
gh api repos/owner/repo/stats/contributors
gh api repos/owner/repo/stats/commit_activity
gh api repos/owner/repo/stats/participation
```

## Synthesis & Documentation
### Research Report Template
```markdown
# Research Report: [Topic]

## Executive Summary
- **Objective**: What was researched
- **Key Findings**: Most important discoveries
- **Recommendation**: What should be done
- **Timeline**: When to implement

## Research Question
[Specific question that was investigated]

## Methodology
- **Sources**: Where information was gathered
- **Tools**: What tools were used
- **Timeframe**: How long research took
- **Scope**: What was included/excluded

## Findings

### Technical Analysis
- **Architecture**: How it works
- **Performance**: Speed, memory, scalability
- **Integration**: How it connects with other systems
- **Maintenance**: Ongoing requirements

### Comparative Analysis
| Feature | Option A | Option B | Option C |
|---------|----------|----------|----------|
| Speed | Fast | Medium | Slow |
| Memory | Low | Medium | High |
| Learning | Easy | Medium | Hard |

### Risk Assessment
- **High Risk**: Major concerns
- **Medium Risk**: Manageable issues  
- **Low Risk**: Minor considerations

## Recommendations

### Primary Recommendation
[Detailed recommendation with reasoning]

### Alternative Options
[Backup options if primary doesn't work]

### Implementation Plan
1. **Phase 1**: Initial steps
2. **Phase 2**: Core implementation
3. **Phase 3**: Optimization and testing

## Next Steps
- [ ] Action item 1
- [ ] Action item 2
- [ ] Follow-up research needed

## References
- [Source 1](url)
- [Source 2](url)
- [Documentation](url)
```

### Knowledge Management
```bash
# Research organization system
mkdir -p research/{2024}/{topic}
echo "# Research Notes: Topic" > research/2024/topic/notes.md
echo "# Sources and References" > research/2024/topic/sources.md
echo "# Code Examples and Tests" > research/2024/topic/examples.md

# Create index
find research/ -name "*.md" | xargs grep -l "# Research" > research/index.txt
```

---
**Priming Active**: Research and investigation patterns loaded. Ready for systematic discovery, analysis, and synthesis of technical information with comprehensive documentation capabilities.