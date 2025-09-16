#!/bin/bash

# AWOC Handoff Performance Optimizer
# Benchmarking and optimization for context handoff operations
# Ensures <1 second save/load targets and <50MB bundle sizes

set -euo pipefail

# Source logging system
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/logging.sh" ]; then
    # shellcheck source=./logging.sh
    source "$SCRIPT_DIR/logging.sh"
    init_logging
else
    log_info() { echo "[INFO] $1" >&2; }
    log_warning() { echo "[WARNING] $1" >&2; }
    log_error() { echo "[ERROR] $1" >&2; }
    log_debug() { echo "[DEBUG] $1" >&2; }
fi

# Configuration
PERF_DIR="${HOME}/.awoc/performance"
BENCHMARK_DIR="$PERF_DIR/benchmarks"
METRICS_FILE="$PERF_DIR/handoff_metrics.json"

# Performance targets
TARGET_SAVE_TIME=1.0      # seconds
TARGET_LOAD_TIME=1.0      # seconds  
TARGET_BUNDLE_SIZE=50     # MB
TARGET_COMPRESSION_RATIO=0.7  # 70% compression

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize performance monitoring
init_performance_monitoring() {
    log_info "Initializing handoff performance monitoring" "HANDOFF_PERF"
    
    # Create directories
    mkdir -p "$BENCHMARK_DIR" "$PERF_DIR"
    
    # Initialize metrics file
    if [ ! -f "$METRICS_FILE" ]; then
        cat > "$METRICS_FILE" << EOF
{
    "version": "1.0.0",
    "created_at": "$(date -Iseconds)",
    "targets": {
        "save_time_seconds": $TARGET_SAVE_TIME,
        "load_time_seconds": $TARGET_LOAD_TIME,
        "bundle_size_mb": $TARGET_BUNDLE_SIZE,
        "compression_ratio": $TARGET_COMPRESSION_RATIO
    },
    "benchmarks": [],
    "optimizations": [],
    "performance_trends": {
        "save_times": [],
        "load_times": [],
        "bundle_sizes": [],
        "compression_ratios": []
    }
}
EOF
    fi
    
    log_info "Performance monitoring initialized" "HANDOFF_PERF"
}

# Benchmark handoff save operation
benchmark_save() {
    local test_type="${1:-standard}"
    local iterations="${2:-5}"
    
    log_info "Benchmarking handoff save: type=$test_type, iterations=$iterations" "HANDOFF_PERF"
    
    local total_time=0
    local total_size=0
    local results=()
    
    echo -e "${BLUE}🚀 Benchmarking Handoff Save Operations${NC}"
    echo "======================================"
    echo "Test Type: $test_type"
    echo "Iterations: $iterations"
    echo ""
    
    for ((i=1; i<=iterations; i++)); do
        echo -n "Iteration $i/$iterations... "
        
        # Measure save time
        local start_time
        start_time=$(date +%s.%N)
        
        # Create test handoff bundle
        local bundle_id
        bundle_id=$("$SCRIPT_DIR/handoff-manager.sh" save "benchmark" "gzip" "medium" 2>/dev/null)
        
        local end_time
        end_time=$(date +%s.%N)
        
        # Calculate duration (using awk instead of bc)
        local duration
        duration=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}")
        
        # Get bundle size
        local bundle_file
        bundle_file=$(find ~/.awoc/handoffs/active -name "${bundle_id}*" -type f 2>/dev/null | head -1)
        local bundle_size=0
        
        if [ -n "$bundle_file" ] && [ -f "$bundle_file" ]; then
            bundle_size=$(stat -c%s "$bundle_file" 2>/dev/null || echo "0")
            bundle_size=$((bundle_size / 1024 / 1024))  # Convert to MB
        fi
        
        # Store results
        results+=("$duration:$bundle_size")
        total_time=$(awk "BEGIN {printf \"%.3f\", $total_time + $duration}")
        total_size=$((total_size + bundle_size))
        
        # Status indicator
        if (( $(awk "BEGIN {print ($duration <= $TARGET_SAVE_TIME)}") )); then
            echo -e "${GREEN}✅ ${duration}s (${bundle_size}MB)${NC}"
        else
            echo -e "${YELLOW}⚠️  ${duration}s (${bundle_size}MB)${NC}"
        fi
        
        # Clean up test bundle
        [ -f "$bundle_file" ] && rm -f "$bundle_file"
        
        # Brief pause between iterations
        sleep 0.1
    done
    
    # Calculate averages
    local avg_time
    local avg_size
    avg_time=$(awk "BEGIN {printf \"%.3f\", $total_time / $iterations}")
    avg_size=$((total_size / iterations))
    
    # Store benchmark results
    store_benchmark_results "save" "$test_type" "$iterations" "$avg_time" "$avg_size"
    
    # Display results
    echo ""
    echo "Benchmark Results:"
    echo "------------------"
    echo "Average Save Time: ${avg_time}s (target: ${TARGET_SAVE_TIME}s)"
    echo "Average Bundle Size: ${avg_size}MB (target: ${TARGET_BUNDLE_SIZE}MB)"
    
    # Performance assessment
    if (( $(awk "BEGIN {print ($avg_time <= $TARGET_SAVE_TIME)}") )); then
        echo -e "Save Performance: ${GREEN}✅ MEETS TARGET${NC}"
    else
        echo -e "Save Performance: ${RED}❌ BELOW TARGET${NC}"
        suggest_save_optimizations "$avg_time" "$avg_size"
    fi
    
    if [ "$avg_size" -le "$TARGET_BUNDLE_SIZE" ]; then
        echo -e "Bundle Size: ${GREEN}✅ MEETS TARGET${NC}"
    else
        echo -e "Bundle Size: ${RED}❌ EXCEEDS TARGET${NC}"
        suggest_size_optimizations "$avg_size"
    fi
}

# Benchmark handoff load operation
benchmark_load() {
    local test_type="${1:-standard}"
    local iterations="${2:-5}"
    
    log_info "Benchmarking handoff load: type=$test_type, iterations=$iterations" "HANDOFF_PERF"
    
    echo -e "${BLUE}📥 Benchmarking Handoff Load Operations${NC}"
    echo "====================================="
    echo "Test Type: $test_type"
    echo "Iterations: $iterations"
    echo ""
    
    # Create test bundle first
    local test_bundle_id
    test_bundle_id=$("$SCRIPT_DIR/handoff-manager.sh" save "benchmark" "gzip" "medium" 2>/dev/null)
    
    if [ -z "$test_bundle_id" ]; then
        echo -e "${RED}❌ Failed to create test bundle${NC}"
        return 1
    fi
    
    local total_time=0
    local results=()
    
    for ((i=1; i<=iterations; i++)); do
        echo -n "Iteration $i/$iterations... "
        
        # Measure load time
        local start_time
        start_time=$(date +%s.%N)
        
        # Load handoff bundle (suppress output)
        "$SCRIPT_DIR/handoff-manager.sh" load "$test_bundle_id" "full" "basic" >/dev/null 2>&1
        
        local end_time
        end_time=$(date +%s.%N)
        
        # Calculate duration (using awk instead of bc)
        local duration
        duration=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}")
        
        results+=("$duration")
        total_time=$(awk "BEGIN {printf \"%.3f\", $total_time + $duration}")
        
        # Status indicator
        if (( $(echo "$duration <= $TARGET_LOAD_TIME" | bc -l) )); then
            echo -e "${GREEN}✅ ${duration}s${NC}"
        else
            echo -e "${YELLOW}⚠️  ${duration}s${NC}"
        fi
        
        sleep 0.1
    done
    
    # Calculate average
    local avg_time
    avg_time=$(awk "BEGIN {printf \"%.3f\", $total_time / $iterations}")
    
    # Store benchmark results
    store_benchmark_results "load" "$test_type" "$iterations" "$avg_time" "0"
    
    # Display results
    echo ""
    echo "Benchmark Results:"
    echo "------------------"
    echo "Average Load Time: ${avg_time}s (target: ${TARGET_LOAD_TIME}s)"
    
    # Performance assessment
    if (( $(echo "$avg_time <= $TARGET_LOAD_TIME" | bc -l) )); then
        echo -e "Load Performance: ${GREEN}✅ MEETS TARGET${NC}"
    else
        echo -e "Load Performance: ${RED}❌ BELOW TARGET${NC}"
        suggest_load_optimizations "$avg_time"
    fi
    
    # Clean up test bundle
    local test_bundle_file
    test_bundle_file=$(find ~/.awoc/handoffs/active -name "${test_bundle_id}*" -type f 2>/dev/null | head -1)
    [ -f "$test_bundle_file" ] && rm -f "$test_bundle_file"
}

# Benchmark compression performance
benchmark_compression() {
    local test_data_size="${1:-10}"  # MB
    
    echo -e "${BLUE}🗜️  Benchmarking Compression Performance${NC}"
    echo "======================================="
    echo ""
    
    # Create test data
    local test_file
    test_file=$(mktemp)
    dd if=/dev/urandom of="$test_file" bs=1M count="$test_data_size" 2>/dev/null
    
    local original_size
    original_size=$(stat -c%s "$test_file")
    
    echo "Test Data: ${test_data_size}MB"
    echo ""
    
    # Test different compression methods
    local methods=("gzip" "bzip2" "xz")
    local best_method=""
    local best_ratio=0
    local best_time=999
    
    for method in "${methods[@]}"; do
        if ! command -v "$method" &> /dev/null; then
            echo "$method: Not available"
            continue
        fi
        
        echo -n "$method: "
        
        local start_time
        start_time=$(date +%s.%N)
        
        case "$method" in
            "gzip")
                gzip -c "$test_file" > "${test_file}.gz"
                local compressed_file="${test_file}.gz"
                ;;
            "bzip2")
                bzip2 -c "$test_file" > "${test_file}.bz2"
                local compressed_file="${test_file}.bz2"
                ;;
            "xz")
                xz -c "$test_file" > "${test_file}.xz"
                local compressed_file="${test_file}.xz"
                ;;
        esac
        
        local end_time
        end_time=$(date +%s.%N)
        
        local duration
        duration=$(awk "BEGIN {printf \"%.3f\", $end_time - $start_time}")
        
        local compressed_size
        compressed_size=$(stat -c%s "$compressed_file" 2>/dev/null || echo "$original_size")
        
        local ratio
        ratio=$(echo "scale=3; $compressed_size / $original_size" | bc -l)
        
        local reduction
        reduction=$(echo "scale=1; (1 - $ratio) * 100" | bc -l)
        
        echo "${duration}s, ${reduction}% reduction (ratio: $ratio)"
        
        # Track best method
        if (( $(echo "$ratio < $best_ratio || $best_ratio == 0" | bc -l) )) && (( $(echo "$duration < 5.0" | bc -l) )); then
            best_method=$method
            best_ratio=$ratio
            best_time=$duration
        fi
        
        rm -f "$compressed_file"
    done
    
    echo ""
    echo "Recommended: $best_method (${best_time}s, ratio: $best_ratio)"
    
    rm -f "$test_file"
}

# Store benchmark results
store_benchmark_results() {
    local operation="$1"
    local test_type="$2"
    local iterations="$3"
    local avg_time="$4"
    local avg_size="$5"
    
    local temp_file
    temp_file=$(mktemp)
    
    jq --arg operation "$operation" \
       --arg test_type "$test_type" \
       --argjson iterations "$iterations" \
       --argjson avg_time "$avg_time" \
       --argjson avg_size "$avg_size" \
       --arg timestamp "$(date -Iseconds)" \
       '.benchmarks += [{
           operation: $operation,
           test_type: $test_type,
           iterations: $iterations,
           avg_time: $avg_time,
           avg_size: $avg_size,
           timestamp: $timestamp
       }] |
       .performance_trends[($operation + "_times")] += [$avg_time]' \
       "$METRICS_FILE" > "$temp_file" && mv "$temp_file" "$METRICS_FILE"
    
    rm -f "$temp_file"
}

# Suggest save optimizations
suggest_save_optimizations() {
    local avg_time="$1"
    local avg_size="$2"
    
    echo ""
    echo -e "${YELLOW}💡 Save Optimization Suggestions:${NC}"
    echo "================================="
    
    if (( $(echo "$avg_time > $TARGET_SAVE_TIME" | bc -l) )); then
        echo "• Enable parallel data collection"
        echo "• Reduce JSON pretty-printing"
        echo "• Implement incremental bundling"
        echo "• Use faster compression algorithm"
    fi
    
    if [ "$avg_size" -gt "$TARGET_BUNDLE_SIZE" ]; then
        echo "• Implement data deduplication"
        echo "• Compress historical context"
        echo "• Remove redundant metadata"
        echo "• Use semantic compression"
    fi
}

# Suggest load optimizations
suggest_load_optimizations() {
    local avg_time="$1"
    
    echo ""
    echo -e "${YELLOW}💡 Load Optimization Suggestions:${NC}"
    echo "================================="
    echo "• Enable lazy loading of non-critical data"
    echo "• Implement bundle caching"
    echo "• Use streaming decompression"
    echo "• Parallel restoration of components"
    echo "• Background validation processing"
}

# Run comprehensive performance test
run_comprehensive_test() {
    echo -e "${BLUE}🔬 AWOC Handoff Performance Test Suite${NC}"
    echo "======================================"
    echo ""
    
    # Initialize if needed
    init_performance_monitoring
    
    # Run benchmarks
    benchmark_save "standard" 3
    echo ""
    benchmark_load "standard" 3
    echo ""
    benchmark_compression 5
    
    # Generate performance report
    echo ""
    generate_performance_report
}

# Generate performance report
generate_performance_report() {
    echo -e "${BLUE}📊 Performance Report${NC}"
    echo "==================="
    echo ""
    
    if [ ! -f "$METRICS_FILE" ]; then
        echo "No performance data available"
        return
    fi
    
    # Latest benchmarks
    local latest_save_time
    local latest_load_time
    latest_save_time=$(jq -r '.benchmarks | map(select(.operation == "save")) | last | .avg_time // 0' "$METRICS_FILE")
    latest_load_time=$(jq -r '.benchmarks | map(select(.operation == "load")) | last | .avg_time // 0' "$METRICS_FILE")
    
    echo "Latest Performance:"
    echo "  Save Time: ${latest_save_time}s (target: ${TARGET_SAVE_TIME}s)"
    echo "  Load Time: ${latest_load_time}s (target: ${TARGET_LOAD_TIME}s)"
    echo ""
    
    # Performance trends
    local save_trend
    local load_trend
    save_trend=$(jq -r '.performance_trends.save_times | if length > 1 then (.[-1] - .[-2]) else 0 end' "$METRICS_FILE")
    load_trend=$(jq -r '.performance_trends.load_times | if length > 1 then (.[-1] - .[-2]) else 0 end' "$METRICS_FILE")
    
    echo "Performance Trends:"
    if (( $(echo "$save_trend < 0" | bc -l) )); then
        echo -e "  Save: ${GREEN}↗️ Improving${NC} (${save_trend}s)"
    elif (( $(echo "$save_trend > 0" | bc -l) )); then
        echo -e "  Save: ${RED}↘️ Degrading${NC} (+${save_trend}s)"
    else
        echo "  Save: ➡️ Stable"
    fi
    
    if (( $(echo "$load_trend < 0" | bc -l) )); then
        echo -e "  Load: ${GREEN}↗️ Improving${NC} (${load_trend}s)"
    elif (( $(echo "$load_trend > 0" | bc -l) )); then
        echo -e "  Load: ${RED}↘️ Degrading${NC} (+${load_trend}s)"
    else
        echo "  Load: ➡️ Stable"
    fi
    
    echo ""
    
    # Overall assessment
    local save_status="❌"
    local load_status="❌"
    
    (( $(echo "$latest_save_time <= $TARGET_SAVE_TIME" | bc -l) )) && save_status="✅"
    (( $(echo "$latest_load_time <= $TARGET_LOAD_TIME" | bc -l) )) && load_status="✅"
    
    echo "Performance Status:"
    echo "  Save Operations: $save_status"
    echo "  Load Operations: $load_status"
    
    if [[ "$save_status" == "✅" && "$load_status" == "✅" ]]; then
        echo -e "  Overall: ${GREEN}✅ ALL TARGETS MET${NC}"
    else
        echo -e "  Overall: ${YELLOW}⚠️  OPTIMIZATION NEEDED${NC}"
    fi
}

# Clean performance data
clean_performance_data() {
    local retention_days="${1:-30}"
    
    echo "Cleaning performance data older than $retention_days days..."
    
    # Clean old benchmark files
    find "$BENCHMARK_DIR" -type f -mtime +"$retention_days" -delete 2>/dev/null || true
    
    # Rotate metrics file if too large
    if [ -f "$METRICS_FILE" ]; then
        local file_size
        file_size=$(stat -c%s "$METRICS_FILE" 2>/dev/null || echo "0")
        local size_mb=$((file_size / 1024 / 1024))
        
        if [ "$size_mb" -gt 10 ]; then
            mv "$METRICS_FILE" "${METRICS_FILE}.old"
            init_performance_monitoring
            echo "Rotated large metrics file (${size_mb}MB)"
        fi
    fi
    
    echo "✅ Performance data cleanup completed"
}

# Usage information
usage() {
    echo "AWOC Handoff Performance Optimizer"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  init                       Initialize performance monitoring"
    echo "  benchmark-save [type] [n]  Benchmark save operations"
    echo "  benchmark-load [type] [n]  Benchmark load operations"
    echo "  benchmark-compression [mb] Test compression methods"
    echo "  test                       Run comprehensive test suite"
    echo "  report                     Generate performance report"
    echo "  clean [days]              Clean old performance data"
    echo "  help                       Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 benchmark-save standard 5"
    echo "  $0 benchmark-load standard 3"
    echo "  $0 benchmark-compression 10"
    echo "  $0 test"
    echo ""
    echo "Performance Targets:"
    echo "  Save Time: ≤${TARGET_SAVE_TIME}s"
    echo "  Load Time: ≤${TARGET_LOAD_TIME}s"
    echo "  Bundle Size: ≤${TARGET_BUNDLE_SIZE}MB"
    echo "  Compression: ≥${TARGET_COMPRESSION_RATIO}"
}

# Main function
main() {
    case "${1:-help}" in
        init)
            init_performance_monitoring
            echo "✅ Performance monitoring initialized"
            ;;
        benchmark-save)
            benchmark_save "${2:-standard}" "${3:-5}"
            ;;
        benchmark-load)
            benchmark_load "${2:-standard}" "${3:-5}"
            ;;
        benchmark-compression)
            benchmark_compression "${2:-10}"
            ;;
        test)
            run_comprehensive_test
            ;;
        report)
            generate_performance_report
            ;;
        clean)
            clean_performance_data "${2:-30}"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            echo "Unknown command: ${1:-}" >&2
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi