# AWOC Background Task Integration
---
name: integrate-background
description: Aggregate and integrate results from background tasks without context pollution
argument-hint: [task-id] [integration-mode] [output-format] [filter]
allowed-tools: [Read, Write, Bash]
schema: integrate-background-v1.0
---

## Overview
Intelligently integrates background task results into main workflow while maintaining context efficiency and preventing token pollution.

## Usage

### Basic Integration
```bash
/integrate-background task-abc123 merge structured
/integrate-background research-def456 append summary  
/integrate-background analysis-789 reference detailed
```

### Batch Integration
```bash
/integrate-background --batch research-task,analysis-task,testing-task merge comprehensive
/integrate-background --filter=completed --since=1h append summary
```

### Selective Integration
```bash
/integrate-background auth-research extract key-findings
/integrate-background performance-analysis summarize recommendations
/integrate-background security-review highlight critical-issues
```

## Execution Flow

### 1. Validate Background Task
```bash
!`scripts/background-task-validator.sh validate "${1}" exists completed`
```

### 2. Analyze Task Output  
```bash
task_id="${1}"
task_dir="${HOME}/.awoc/background/tasks/${task_id}"

# Load task configuration
task_config=$(cat "${task_dir}/task-config.json")
task_type=$(echo "$task_config" | jq -r '.task_type')
output_file=$(echo "$task_config" | jq -r '.output_file')
task_status=$(echo "$task_config" | jq -r '.status')

# Validate task completion
if [[ "$task_status" != "completed" ]]; then
    echo "⚠️  Task ${task_id} status: ${task_status}"
    echo "Available options:"
    echo "1. Integrate partial results"
    echo "2. Wait for completion" 
    echo "3. Force integration"
    
    # Handle user choice or default behavior
    scripts/partial-integration-handler.sh handle "$task_id" "$task_status"
fi
```

### 3. Determine Integration Strategy
Based on integration mode and content analysis:

```bash
integration_mode="${2:-smart}"

case "$integration_mode" in
    "merge")
        # Intelligent content merging
        scripts/content-merger.sh merge "$output_file" "$task_type"
        ;;
    "append") 
        # Add to existing content
        scripts/content-appender.sh append "$output_file" "${3:-structured}"
        ;;
    "reference")
        # Create reference links without importing content
        scripts/reference-creator.sh create "$task_id" "$output_file" "${3:-summary}"
        ;;
    "extract")
        # Extract specific information only
        scripts/content-extractor.sh extract "$output_file" "${3:-key-points}"
        ;;
    "summarize")
        # Create condensed summary
        scripts/content-summarizer.sh summarize "$output_file" "${3:-executive}"
        ;;
    "smart")
        # Automatic mode selection based on content and context
        integration_mode=$(scripts/integration-mode-selector.sh select "$task_id" "$task_type" "$output_file")
        echo "🤖 Auto-selected integration mode: $integration_mode"
        ;;
esac
```

### 4. Content Processing and Filtering
Apply filters to reduce context pollution:

```bash
filter_type="${4:-relevant}"

case "$filter_type" in
    "key-findings")
        # Extract only the most important findings
        processed_content=$(scripts/content-filter.sh extract-key-findings "$output_file")
        ;;
    "recommendations")
        # Focus on actionable recommendations
        processed_content=$(scripts/content-filter.sh extract-recommendations "$output_file")
        ;;
    "critical-issues")
        # Highlight critical problems or blockers
        processed_content=$(scripts/content-filter.sh extract-critical "$output_file")
        ;;
    "summary")
        # High-level summary only
        processed_content=$(scripts/content-filter.sh create-summary "$output_file" 200)
        ;;
    "detailed")
        # Full content but structured
        processed_content=$(scripts/content-filter.sh structure-detailed "$output_file")
        ;;
    "relevant")
        # Context-aware relevance filtering
        processed_content=$(scripts/content-filter.sh filter-relevant "$output_file" "${CURRENT_CONTEXT:-general}")
        ;;
esac
```

### 5. Token Budget Management
Monitor and control token usage during integration:

```bash
# Check current context usage
current_tokens=$(scripts/context-monitor.sh get-current-tokens)
integration_tokens=$(echo "$processed_content" | wc -w | awk '{print int($1 * 1.3)}')
total_projected=$((current_tokens + integration_tokens))

# Apply token budget controls
max_integration_tokens=2000
warning_threshold=85  # % of context limit

if [[ $integration_tokens -gt $max_integration_tokens ]]; then
    echo "⚠️  Integration content ($integration_tokens tokens) exceeds budget ($max_integration_tokens tokens)"
    
    # Offer reduction options
    echo "Options:"
    echo "1. Compress content (recommended)"
    echo "2. Create reference only"
    echo "3. Split into smaller chunks"
    
    # Auto-compress if budget exceeded
    processed_content=$(scripts/content-compressor.sh compress "$processed_content" $max_integration_tokens)
    echo "✓ Content compressed to $(echo "$processed_content" | wc -w | awk '{print int($1 * 1.3)}') tokens"
fi

# Check context threshold warnings
usage_percentage=$(scripts/context-monitor.sh get-usage-percentage)
if [[ $usage_percentage -gt $warning_threshold ]]; then
    echo "⚠️  Context usage high: ${usage_percentage}%"
    scripts/integration-optimizer.sh optimize-for-context "$processed_content"
fi
```

### 6. Execute Integration
Perform the actual integration based on selected strategy:

```bash
case "$integration_mode" in
    "merge")
        # Merge with existing content intelligently
        target_file="${INTEGRATION_TARGET:-integration-results.md}"
        
        if [[ -f "$target_file" ]]; then
            # Merge with existing content
            scripts/content-merger.sh intelligent-merge "$target_file" "$processed_content" "$task_type"
        else
            # Create new integrated document
            echo "# Integrated Results from Background Tasks" > "$target_file"
            echo "" >> "$target_file"
            echo "$processed_content" >> "$target_file"
        fi
        
        echo "✓ Content merged into: $target_file"
        ;;
        
    "append")
        # Simple append to specified or default file
        target_file="${INTEGRATION_TARGET:-background-results.md}"
        
        echo "" >> "$target_file"
        echo "## Results from Task: $task_id" >> "$target_file"
        echo "**Type**: $task_type | **Completed**: $(date)" >> "$target_file"
        echo "" >> "$target_file"
        echo "$processed_content" >> "$target_file"
        
        echo "✓ Content appended to: $target_file"
        ;;
        
    "reference")
        # Create reference without importing full content
        reference_content="
## Background Task Reference: $task_id

**Task Type**: $task_type  
**Status**: $task_status  
**Output File**: $output_file  
**Results Summary**: $(scripts/content-summarizer.sh one-line "$output_file")

**Full Results Available**: [View Results]($output_file)
"
        echo "$reference_content"
        
        # Optionally save to reference file
        if [[ -n "${INTEGRATION_TARGET:-}" ]]; then
            echo "$reference_content" >> "$INTEGRATION_TARGET"
            echo "✓ Reference added to: $INTEGRATION_TARGET"
        fi
        ;;
        
    "extract"|"summarize")
        # Direct output of processed content
        echo "## Extracted Results: $task_id"
        echo ""
        echo "$processed_content"
        
        # Save if target specified
        if [[ -n "${INTEGRATION_TARGET:-}" ]]; then
            echo "## Extracted Results: $task_id" >> "$INTEGRATION_TARGET"
            echo "" >> "$INTEGRATION_TARGET" 
            echo "$processed_content" >> "$INTEGRATION_TARGET"
            echo "✓ Extracted content saved to: $INTEGRATION_TARGET"
        fi
        ;;
esac
```

### 7. Update Integration Registry
Track integration for future reference and analysis:

```bash
!`scripts/integration-registry.sh log "$task_id" "$integration_mode" "$filter_type" "$integration_tokens" "$target_file"`
```

## Integration Modes Deep Dive

### Smart Mode (Automatic Selection)
Analyzes content and context to choose optimal integration strategy:

```bash
select_smart_integration() {
    local task_type="$1"
    local content_size="$2"  # in tokens
    local current_context="$3"  # current context usage %
    
    # Decision matrix
    if [[ $content_size -lt 500 && $current_context -lt 60 ]]; then
        echo "merge"
    elif [[ $content_size -lt 1500 && $current_context -lt 80 ]]; then
        echo "append"
    elif [[ $current_context -gt 85 ]]; then
        echo "reference" 
    else
        case "$task_type" in
            "research"|"analysis")
                echo "summarize"
                ;;
            "testing"|"implementation")
                echo "extract"
                ;;
            *)
                echo "reference"
                ;;
        esac
    fi
}
```

### Merge Mode (Intelligent Content Merging)
Combines background results with existing content:

```bash
intelligent_merge() {
    local target_file="$1"
    local new_content="$2"
    local task_type="$3"
    
    # Identify merge points
    merge_points=$(scripts/merge-point-detector.sh find "$target_file" "$task_type")
    
    # Perform context-aware merging
    for point in $merge_points; do
        scripts/content-merger.sh merge-at-point "$target_file" "$new_content" "$point"
    done
    
    # Remove duplicates and optimize structure
    scripts/content-optimizer.sh deduplicate-and-structure "$target_file"
}
```

### Extract Mode (Selective Information Extraction)
Pulls specific information types from background results:

```bash
extract_specific_info() {
    local content="$1"
    local extract_type="$2"
    
    case "$extract_type" in
        "key-findings")
            echo "$content" | scripts/nlp-extractor.sh extract-findings
            ;;
        "recommendations")
            echo "$content" | scripts/nlp-extractor.sh extract-recommendations
            ;;
        "code-snippets")
            echo "$content" | scripts/code-extractor.sh extract-code-blocks
            ;;
        "issues")
            echo "$content" | scripts/nlp-extractor.sh extract-problems
            ;;
        "metrics")
            echo "$content" | scripts/data-extractor.sh extract-metrics
            ;;
    esac
}
```

## Context Optimization Strategies

### Token-Aware Integration
Dynamically adjust integration depth based on available context:

```bash
adaptive_integration() {
    local available_tokens="$1"
    local content="$2"
    local priority="$3"
    
    if [[ $available_tokens -gt 5000 ]]; then
        # High budget - detailed integration
        echo "$content"
    elif [[ $available_tokens -gt 2000 ]]; then
        # Medium budget - structured summary
        scripts/content-compressor.sh structured-summary "$content" $((available_tokens * 7 / 10))
    else
        # Low budget - key points only
        scripts/content-compressor.sh key-points "$content" $((available_tokens / 2))
    fi
}
```

### Deduplication and Compression
Remove redundant information and compress content:

```bash
optimize_integrated_content() {
    local content="$1"
    local target_size="$2"
    
    # Remove duplicates
    deduplicated=$(scripts/content-deduplicator.sh process "$content")
    
    # Compress to target size
    compressed=$(scripts/content-compressor.sh compress-to-size "$deduplicated" "$target_size")
    
    # Maintain key information
    optimized=$(scripts/content-optimizer.sh preserve-key-info "$compressed")
    
    echo "$optimized"
}
```

### Progressive Disclosure
Present information in layers of detail:

```bash
progressive_integration() {
    local content="$1"
    local task_type="$2"
    
    # Executive summary (always shown)
    summary=$(scripts/content-summarizer.sh executive-summary "$content")
    
    # Key findings (shown if space available)
    key_findings=$(scripts/content-extractor.sh key-findings "$content")
    
    # Detailed results (reference only)
    detail_reference="[Full details available in background task results]"
    
    # Construct progressive disclosure
    echo "### Executive Summary"
    echo "$summary"
    echo ""
    echo "### Key Findings" 
    echo "$key_findings"
    echo ""
    echo "$detail_reference"
}
```

## Quality Assurance and Validation

### Integration Quality Metrics
Monitor the quality of integration results:

```bash
assess_integration_quality() {
    local task_id="$1" 
    local integrated_content="$2"
    local original_content="$3"
    
    # Completeness check
    completeness=$(scripts/quality-assessor.sh check-completeness "$integrated_content" "$original_content")
    
    # Coherence check
    coherence=$(scripts/quality-assessor.sh check-coherence "$integrated_content")
    
    # Information density
    density=$(scripts/quality-assessor.sh check-density "$integrated_content")
    
    # Overall quality score
    quality_score=$(scripts/quality-assessor.sh calculate-score "$completeness" "$coherence" "$density")
    
    echo "Integration Quality Report:"
    echo "Completeness: $completeness"
    echo "Coherence: $coherence"
    echo "Information Density: $density"
    echo "Overall Score: $quality_score"
}
```

### Validation and Testing
Ensure integration doesn't break existing workflows:

```bash
validate_integration() {
    local integrated_file="$1"
    
    # Check file integrity
    if ! scripts/file-validator.sh validate "$integrated_file"; then
        echo "❌ File validation failed"
        return 1
    fi
    
    # Check context usage
    new_usage=$(scripts/context-monitor.sh estimate-file-tokens "$integrated_file")
    if [[ $new_usage -gt ${MAX_INTEGRATION_TOKENS:-3000} ]]; then
        echo "⚠️  Integration exceeds token budget: $new_usage tokens"
        return 1  
    fi
    
    # Check content quality
    quality=$(scripts/content-quality-checker.sh check "$integrated_file")
    if [[ $quality -lt 70 ]]; then
        echo "⚠️  Integration quality below threshold: $quality%"
        return 1
    fi
    
    echo "✅ Integration validation passed"
    return 0
}
```

## Error Handling and Recovery

### Failed Integration Recovery
Handle various integration failure scenarios:

```bash
handle_integration_failure() {
    local error_type="$1"
    local task_id="$2"
    local attempted_mode="$3"
    
    case "$error_type" in
        "content_too_large")
            echo "Retrying with compression..."
            /integrate-background "$task_id" summarize compressed
            ;;
        "context_overflow")
            echo "Switching to reference mode..."
            /integrate-background "$task_id" reference summary
            ;;
        "format_incompatible")
            echo "Converting format..."
            scripts/format-converter.sh convert "$task_id" "$attempted_mode"
            ;;
        "merge_conflicts")
            echo "Manual review required for merge conflicts"
            scripts/conflict-resolver.sh create-review "$task_id"
            ;;
    esac
}
```

### Rollback Mechanism
Ability to undo problematic integrations:

```bash
rollback_integration() {
    local task_id="$1"
    local rollback_point="${2:-last_known_good}"
    
    # Find integration record
    integration_record=$(scripts/integration-registry.sh find "$task_id")
    
    # Restore to previous state
    scripts/file-history-manager.sh restore "$rollback_point"
    
    # Update registry
    scripts/integration-registry.sh mark-rolled-back "$task_id"
    
    echo "✅ Integration rolled back successfully"
}
```

## Advanced Integration Examples

### Multi-Task Research Integration
```bash
# Integrate multiple related research tasks
research_tasks=("api-research-123" "competitor-analysis-456" "tech-eval-789")

for task_id in "${research_tasks[@]}"; do
    /integrate-background "$task_id" extract key-findings
done

# Create comprehensive research report
scripts/multi-task-synthesizer.sh create-research-report "${research_tasks[@]}"
```

### Development Workflow Integration
```bash
# Integrate development workflow results
/integrate-background design-review merge detailed
/integrate-background security-analysis extract critical-issues
/integrate-background performance-tests summarize recommendations
/integrate-background code-review append structured

# Generate development summary
scripts/dev-workflow-synthesizer.sh create-summary
```

### Quality Assurance Pipeline
```bash
# Integrate QA results
/integrate-background unit-tests extract coverage-metrics
/integrate-background integration-tests summarize results
/integrate-background security-scan extract vulnerabilities
/integrate-background performance-test reference detailed

# Create QA dashboard
scripts/qa-dashboard-generator.sh update-dashboard
```

---

**Integration Success Metrics:**
- **Context Efficiency**: Token usage per integration  
- **Information Retention**: Percentage of key information preserved
- **Quality Score**: Overall integration quality rating
- **User Satisfaction**: Usefulness of integrated results