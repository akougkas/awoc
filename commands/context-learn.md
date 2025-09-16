# Context Learn Command - AWOC 2.0

Machine learning system for continuous improvement of context management with adaptive optimization.

## Usage

```bash
/context-learn [mode] [options]
```

## Learning Modes

### Model Updates
```bash
/context-learn models
/context-learn models --from-sessions=last-week
/context-learn models --update-all
```

Update ML prediction models from recent session data:
- Prediction accuracy improvement with new training data
- Pattern recognition enhancement with recent examples
- Model weights optimization based on success outcomes
- Performance metrics recalibration with latest results

### Pattern Analysis
```bash
/context-learn patterns
/context-learn patterns --type=optimization
/context-learn patterns --analyze-failures
```

Deep learning from usage patterns and behaviors:
- Optimization strategy effectiveness learning
- Agent coordination pattern recognition
- Context growth behavior analysis
- User preference and workflow pattern detection

### Threshold Optimization
```bash
/context-learn thresholds
/context-learn thresholds --task-type=complex
/context-learn thresholds --adaptive
```

Dynamic threshold adjustment based on performance data:
- Context limit optimization based on success rates
- Risk threshold calibration using overflow prevention data
- Agent coordination thresholds based on efficiency metrics
- Optimization trigger points based on effectiveness analysis

### Success Rate Analysis
```bash
/context-learn success-rates
/context-learn success-rates --by-strategy
/context-learn success-rates --trend-analysis
```

Analyze and improve success rates across all operations:
- Strategy effectiveness measurement with statistical analysis
- Failure pattern identification and prevention
- Success factor correlation analysis
- Performance trend identification and projection

### Behavioral Learning
```bash
/context-learn behavior
/context-learn behavior --user-patterns
/context-learn behavior --context-preferences
```

Learn from user behavior and context usage patterns:
- Task complexity preference learning
- Optimization timing preference detection
- Agent usage pattern recognition
- Context size preference analysis

## Learning Targets

### Prediction Accuracy
```bash
/context-learn --target=prediction-accuracy --min-improvement=5%
```
- Overflow prediction accuracy enhancement (target: 85%+)
- Optimization opportunity detection improvement
- Agent performance forecasting accuracy
- Resource usage prediction precision

### Optimization Effectiveness
```bash
/context-learn --target=optimization --effectiveness-threshold=90%
```
- Strategy selection improvement based on context analysis
- Timing optimization for maximum effectiveness
- Resource utilization efficiency enhancement
- Success rate improvement across all operations

### Adaptive Thresholds
```bash
/context-learn --target=thresholds --adaptive-range=15%
```
- Dynamic threshold adjustment based on performance
- Context-aware limit optimization
- Risk level calibration with prevention success rates
- Performance-based trigger point optimization

## Learning Data Sources

### Session History
```bash
/context-learn --source=sessions --period=30days
```
- Complete session lifecycle data analysis
- Token usage patterns and growth behaviors
- Optimization event outcomes and effectiveness
- Agent coordination performance metrics

### Optimization Logs
```bash
/context-learn --source=optimization --include-failures
```
- Strategy execution results and performance metrics
- Timing effectiveness and resource utilization
- Success/failure pattern identification
- Performance improvement opportunity analysis

### Risk Assessment Data
```bash
/context-learn --source=risk-assessments --prediction-validation
```
- Risk prediction accuracy validation
- Overflow prevention success rate analysis
- Early warning system effectiveness measurement
- Threshold optimization based on prevention outcomes

### Agent Performance Metrics
```bash
/context-learn --source=agent-metrics --coordination-analysis
```
- Individual agent efficiency trends
- Multi-agent coordination effectiveness
- Context sharing success rates
- Workload balancing optimization opportunities

## Implementation

The command integrates with the complete AWOC 2.0 learning framework:

```bash
# Determine learning mode and parameters
learning_mode="${1:-models}"
learning_source="${2:-sessions}"
learning_period="${3:-7days}"

# Set up learning environment
SESSIONS_DIR="${AWOC_DIR}/sessions"
LEARNING_DIR="${AWOC_DIR}/intelligence/learning"
MODEL_DIR="${AWOC_DIR}/intelligence/models"

mkdir -p "$LEARNING_DIR" "$MODEL_DIR"

case "$learning_mode" in
    "models")
        # Update ML prediction models
        echo "Updating ML models from recent session data..."
        
        # Collect training data from specified period
        training_data="${LEARNING_DIR}/training_data_$(date +%s).json"
        scripts/context-intelligence.sh learn update_models "$SESSIONS_DIR" > "$training_data"
        
        # Update pattern recognition models
        scripts/pattern-analyzer.py analyze --session-file="${SESSIONS_DIR}/consolidated_history.jsonl" --output-file="${LEARNING_DIR}/updated_patterns.json"
        
        # Validate model improvements
        validation_results=$(scripts/context-intelligence.sh predict validation "$training_data")
        echo "$validation_results"
        ;;
        
    "patterns")
        # Analyze behavioral patterns for optimization
        echo "Analyzing patterns for strategy optimization..."
        
        pattern_type="${4:-optimization}"
        scripts/context-intelligence.sh patterns "${SESSIONS_DIR}/session_history.jsonl" "$pattern_type"
        
        # Generate pattern-based recommendations
        scripts/pattern-analyzer.py report --session-file="${SESSIONS_DIR}/session_history.jsonl" --output-file="${LEARNING_DIR}/pattern_report_$(date +%s).json"
        ;;
        
    "thresholds")
        # Optimize dynamic thresholds based on performance
        echo "Optimizing thresholds based on performance data..."
        
        task_type="${4:-all_tasks}"
        scripts/context-intelligence.sh learn optimize_thresholds "$task_type" "${SESSIONS_DIR}/performance_history.jsonl"
        
        # Update settings with optimized thresholds
        update_threshold_settings
        ;;
        
    "success-rates")
        # Analyze and improve success rates
        echo "Analyzing success rates for improvement opportunities..."
        
        success_analysis="${LEARNING_DIR}/success_analysis_$(date +%s).json"
        analyze_success_rates > "$success_analysis"
        
        # Generate improvement recommendations
        generate_improvement_recommendations "$success_analysis"
        ;;
        
    "behavior")
        # Learn from user behavior patterns
        echo "Learning from user behavior and preferences..."
        
        behavior_patterns="${LEARNING_DIR}/behavior_patterns_$(date +%s).json"
        analyze_user_behavior > "$behavior_patterns"
        
        # Update user preference models
        update_preference_models "$behavior_patterns"
        ;;
        
    *)
        show_learning_capabilities
        ;;
esac

# Log learning activity
echo "{\"timestamp\":$(date +%s),\"mode\":\"$learning_mode\",\"source\":\"$learning_source\",\"period\":\"$learning_period\"}" >> "${LEARNING_DIR}/learning_history.jsonl"
```

## Learning Functions

### Model Update Functions
```bash
analyze_success_rates() {
    local optimization_logs="${AWOC_DIR}/optimization"
    local prevention_logs="${AWOC_DIR}/recovery/prevention"
    
    python3 -c "
import json
import glob
from datetime import datetime, timedelta

# Analyze optimization success rates
optimization_files = glob.glob('$optimization_logs/*.json')
total_optimizations = 0
successful_optimizations = 0
strategy_success = {}

for file_path in optimization_files:
    try:
        with open(file_path, 'r') as f:
            data = json.load(f)
        
        total_optimizations += 1
        success = data.get('success', False)
        
        if success:
            successful_optimizations += 1
        
        # Track strategy success
        strategies = data.get('strategies_executed', [])
        for strategy_info in strategies:
            strategy = strategy_info.split(':')[0] if ':' in str(strategy_info) else strategy_info
            if strategy not in strategy_success:
                strategy_success[strategy] = {'total': 0, 'success': 0}
            strategy_success[strategy]['total'] += 1
            if success:
                strategy_success[strategy]['success'] += 1
    except:
        continue

# Calculate rates
overall_success_rate = successful_optimizations / total_optimizations if total_optimizations > 0 else 0

strategy_rates = {}
for strategy, counts in strategy_success.items():
    strategy_rates[strategy] = counts['success'] / counts['total'] if counts['total'] > 0 else 0

results = {
    'timestamp': int(datetime.now().timestamp()),
    'total_optimizations': total_optimizations,
    'successful_optimizations': successful_optimizations,  
    'overall_success_rate': round(overall_success_rate, 3),
    'strategy_success_rates': {k: round(v, 3) for k, v in strategy_rates.items()},
    'learning_insights': generate_learning_insights(strategy_rates)
}

print(json.dumps(results, indent=2))
"
}

analyze_user_behavior() {
    python3 -c "
import json
import glob
from collections import defaultdict
from datetime import datetime

# Analyze user behavior patterns
sessions_dir = '${SESSIONS_DIR}'
session_files = glob.glob(f'{sessions_dir}/*.json')

behavior_patterns = {
    'optimization_preferences': defaultdict(int),
    'timing_patterns': defaultdict(int), 
    'task_complexity_preferences': defaultdict(int),
    'agent_usage_patterns': defaultdict(int)
}

for file_path in session_files:
    try:
        with open(file_path, 'r') as f:
            session = json.load(f)
        
        # Optimization preferences
        opt_mode = session.get('optimization_mode', 'auto')
        behavior_patterns['optimization_preferences'][opt_mode] += 1
        
        # Timing patterns
        hour = datetime.fromtimestamp(session.get('timestamp', 0)).hour
        behavior_patterns['timing_patterns'][f'hour_{hour}'] += 1
        
        # Task complexity
        complexity = session.get('task_complexity', 'medium')
        behavior_patterns['task_complexity_preferences'][complexity] += 1
        
        # Agent usage
        agents = session.get('agents_used', [])
        for agent in agents:
            behavior_patterns['agent_usage_patterns'][agent] += 1
            
    except:
        continue

# Convert to regular dict for JSON serialization
results = {
    'timestamp': int(datetime.now().timestamp()),
    'behavior_patterns': {k: dict(v) for k, v in behavior_patterns.items()},
    'insights': generate_behavior_insights(behavior_patterns)
}

print(json.dumps(results, indent=2))
"
}

update_threshold_settings() {
    local settings_file="settings.json"
    local optimized_thresholds="${MODEL_DIR}/optimized_thresholds.json"
    
    if [[ -f "$optimized_thresholds" ]]; then
        # Update settings.json with optimized thresholds
        python3 -c "
import json

# Load current settings
with open('$settings_file', 'r') as f:
    settings = json.load(f)

# Load optimized thresholds
with open('$optimized_thresholds', 'r') as f:
    thresholds = json.load(f)

# Update context thresholds
if 'context' in settings and 'monitoring' in settings['context']:
    current_thresholds = settings['context']['monitoring']['thresholds']
    
    # Apply optimizations while preserving structure
    for threshold_type, value in thresholds.get('optimized_values', {}).items():
        if threshold_type in current_thresholds:
            current_thresholds[threshold_type] = value

    # Save updated settings
    with open('$settings_file', 'w') as f:
        json.dump(settings, f, indent=2)
    
    print('Thresholds updated successfully')
else:
    print('Warning: Could not update thresholds - settings structure not found')
"
    fi
}
```

## Output Examples

### Model Update Results
```
=== ML Model Update Results ===

Training Data Analysis:
  Sessions Analyzed: 127 (last 7 days)
  Optimization Events: 43
  Prevention Events: 18
  Success Outcomes: 92%

Model Performance Improvements:
  Overflow Prediction: 81.2% → 84.7% accuracy (+3.5%)
  Optimization Detection: 78.9% → 82.1% accuracy (+3.2%)
  Agent Coordination: 73.4% → 76.8% accuracy (+3.4%)
  
Strategy Effectiveness Learning:
  Semantic Compression: 89% success rate (was 85%)
  Context Sharing: 76% success rate (was 72%)
  Handoff Optimization: 94% success rate (was 92%)
  
Updated Models:
  ✓ Pattern recognition model retrained (2,847 new samples)
  ✓ Prediction ensemble weights optimized
  ✓ Threshold models recalibrated
  ✓ Success rate predictors updated

Next Model Update: Scheduled in 7 days (or after 50 new sessions)
```

### Pattern Learning Analysis
```
=== Pattern Learning Analysis ===

Discovered Patterns:
  High-efficiency Optimization Windows:
    • 09:00-11:00: 94% success rate (morning focus period)
    • 14:00-16:00: 87% success rate (afternoon productivity)
    • 20:00-22:00: 91% success rate (evening deep work)
    
  Suboptimal Periods:
    • 12:00-13:00: 64% success rate (lunch context switching)
    • 17:00-19:00: 68% success rate (end-of-day fatigue)

Task Complexity Correlations:
  Simple Tasks: Best with lightweight optimization (15% reduction target)
  Medium Tasks: Optimal with standard optimization (25% reduction target)  
  Complex Tasks: Require aggressive optimization (35% reduction target)
  
Agent Coordination Insights:
  2 Agents: 92% efficiency (optimal for most tasks)
  3 Agents: 84% efficiency (good for complex tasks)
  4+ Agents: 71% efficiency (coordination overhead)

Learning Recommendations:
  ✓ Adjust optimization timing based on efficiency windows
  ✓ Task-specific optimization targets for better results
  ✓ Agent count optimization based on task complexity
  ✓ Context sharing prioritization during coordination peaks
```

### Threshold Optimization Results
```
=== Dynamic Threshold Optimization ===

Current vs Optimized Thresholds:
  Warning Threshold: 70% → 65% (earlier intervention)
  Optimization Threshold: 80% → 75% (proactive optimization)
  Critical Threshold: 90% → 85% (increased safety margin)
  Emergency Threshold: 95% → 92% (faster emergency response)

Performance Impact Predictions:
  Overflow Prevention: 89% → 94% success rate (+5%)
  False Positive Reduction: 23% → 15% rate (-8%)
  Average Optimization Time: 18s → 14s (-4s improvement)
  Emergency Activations: 12/month → 7/month (-42%)

Task-Specific Optimizations:
  Simple Tasks: More relaxed thresholds (higher limits)
  Complex Tasks: Tighter thresholds (earlier intervention)
  Multi-Agent: Reduced thresholds (coordination overhead)
  Background Tasks: Adaptive thresholds (resource availability)

Validation Results:
  Simulated Performance: +12% overall improvement
  Confidence Interval: 95% (high reliability)
  A/B Testing Recommended: 2-week trial period
  Rollback Plan: Automated if success rate drops below 85%
```

## Advanced Learning Features

### Continuous Learning Pipeline
- **Real-time Data Ingestion**: Streaming session data for immediate model updates
- **Incremental Learning**: Online learning algorithms for continuous improvement
- **Performance Monitoring**: Automated accuracy tracking with degradation detection
- **Model Versioning**: Version control for models with rollback capabilities

### Multi-Dimensional Learning
- **Temporal Patterns**: Time-based behavior learning for scheduling optimization
- **Contextual Learning**: Task-specific pattern recognition and adaptation
- **User Personalization**: Individual preference learning and customization
- **Environmental Adaptation**: System load and resource availability learning

### Intelligent Feedback Loops
- **Success Prediction**: Learn from prediction accuracy to improve models
- **Strategy Optimization**: Continuous improvement of optimization strategies
- **Threshold Adaptation**: Dynamic adjustment based on performance outcomes
- **Pattern Evolution**: Recognition of changing usage patterns and adaptation

### Knowledge Transfer
- **Cross-Session Learning**: Knowledge sharing across different work sessions
- **Agent Learning**: Individual agent performance improvement through experience
- **Strategy Generalization**: Successful patterns applied across contexts
- **Predictive Insights**: Future behavior prediction based on learned patterns

This command transforms context management from static rules to adaptive intelligence, enabling continuous improvement and personalization that achieves increasingly better performance over time.