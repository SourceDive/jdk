#!/bin/bash

# 自动重试构建脚本

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查构建状态
check_build_status() {
    local response=$(curl -s "https://api.github.com/repos/SourceDive/jdk/actions/runs?branch=cursor/download-jdk-compilation-artifacts-8976&per_page=1")
    local status=$(echo "$response" | grep -o '"status":"[^"]*"' | head -1 | cut -d'"' -f4)
    local conclusion=$(echo "$response" | grep -o '"conclusion":"[^"]*"' | head -1 | cut -d'"' -f4)
    local html_url=$(echo "$response" | grep -o '"html_url":"[^"]*"' | head -1 | cut -d'"' -f4)
    
    echo "$status|$conclusion|$html_url"
}

# 触发重试构建
trigger_retry() {
    local retry_count=$1
    
    log "触发第 $retry_count 次重试构建..."
    
    # 创建重试提交
    git add .
    git commit -m "retry: 第${retry_count}次重试构建 - $(date '+%Y-%m-%d %H:%M:%S')" || true
    
    # 推送到远程
    git push origin cursor/download-jdk-compilation-artifacts-8976
    
    if [ $? -eq 0 ]; then
        success "重试构建已触发"
        return 0
    else
        error "重试构建触发失败"
        return 1
    fi
}

# 监控构建直到成功
monitor_until_success() {
    local max_retries=3
    local retry_count=0
    
    while [ $retry_count -le $max_retries ]; do
        log "检查构建状态..."
        
        local status_info=$(check_build_status)
        IFS='|' read -r status conclusion html_url <<< "$status_info"
        
        echo "状态: $status"
        if [ -n "$conclusion" ] && [ "$conclusion" != "null" ]; then
            echo "结论: $conclusion"
        fi
        echo "链接: $html_url"
        echo ""
        
        case "$status" in
            "completed")
                if [ "$conclusion" = "success" ]; then
                    success "🎉 构建成功完成！"
                    success "下载链接: $html_url"
                    return 0
                else
                    error "构建失败，结论: $conclusion"
                    if [ $retry_count -lt $max_retries ]; then
                        retry_count=$((retry_count + 1))
                        log "准备第 $retry_count 次重试..."
                        sleep 10
                        trigger_retry $retry_count
                        log "等待构建开始..."
                        sleep 30
                    else
                        error "已达到最大重试次数 ($max_retries)"
                        return 1
                    fi
                fi
                ;;
            "in_progress"|"queued")
                log "构建进行中，等待 30 秒后再次检查..."
                sleep 30
                ;;
            *)
                warning "未知状态: $status，等待 30 秒后再次检查..."
                sleep 30
                ;;
        esac
    done
    
    error "监控超时"
    return 1
}

# 主函数
main() {
    echo "=== JDK构建自动重试脚本 ==="
    echo ""
    
    # 检查当前状态
    log "检查当前构建状态..."
    local status_info=$(check_build_status)
    IFS='|' read -r status conclusion html_url <<< "$status_info"
    
    echo "当前状态: $status"
    if [ -n "$conclusion" ] && [ "$conclusion" != "null" ]; then
        echo "当前结论: $conclusion"
    fi
    echo "详情链接: $html_url"
    echo ""
    
    if [ "$status" = "completed" ] && [ "$conclusion" = "success" ]; then
        success "构建已经成功，无需重试！"
        success "下载链接: $html_url"
        exit 0
    elif [ "$status" = "completed" ] && [ "$conclusion" = "failure" ]; then
        warning "构建失败，开始自动重试..."
        monitor_until_success
    elif [ "$status" = "in_progress" ] || [ "$status" = "queued" ]; then
        warning "构建进行中，开始监控..."
        monitor_until_success
    else
        warning "未知状态，开始监控..."
        monitor_until_success
    fi
}

# 运行主函数
main "$@"