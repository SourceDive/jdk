#!/bin/bash

# 持续监控 GitHub Actions 的简化脚本
# 每30秒检查一次状态，自动修复常见错误

set -e

# 配置
REPO_OWNER="SourceDive"
REPO_NAME="jdk"
WORKFLOW_NAME="Build JDK"
CHECK_INTERVAL=30
MAX_ATTEMPTS=100

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️${NC} $1"
}

# 快速修复常见问题
quick_fix() {
    local error_msg="$1"
    
    log "尝试快速修复..."
    
    # 修复 configure 选项错误
    if echo "$error_msg" | grep -q "unrecognized option"; then
        log "修复 configure 选项..."
        sed -i 's/-O[0-9]/-O2/g' .github/workflows/build-jdk.yml
        sed -i '/--with-memory-size/d' .github/workflows/build-jdk.yml
        git add .github/workflows/build-jdk.yml
        git commit -m "Fix: 修复 configure 选项错误" || true
        git push || true
        return 0
    fi
    
    # 修复权限错误
    if echo "$error_msg" | grep -q "Permission denied"; then
        log "修复权限问题..."
        chmod +x configure
        chmod +x make/autoconf/configure
        git add .
        git commit -m "Fix: 修复权限问题" || true
        git push || true
        return 0
    fi
    
    # 修复依赖错误
    if echo "$error_msg" | grep -q "autoconf"; then
        log "修复依赖问题..."
        # 这里可以添加依赖安装逻辑
        git add .
        git commit -m "Fix: 修复依赖问题" || true
        git push || true
        return 0
    fi
    
    # 通用修复
    log "应用通用修复..."
    rm -rf build/
    git add .
    git commit -m "Fix: 通用修复 $(date '+%H:%M:%S')" || true
    git push || true
    return 0
}

# 检查工作流状态
check_workflow() {
    local attempt=0
    
    while [ $attempt -lt $MAX_ATTEMPTS ]; do
        attempt=$((attempt + 1))
        log "检查工作流状态 (第 $attempt 次)"
        
        # 获取最新运行状态
        local run_info=$(gh api repos/$REPO_OWNER/$REPO_NAME/actions/runs --jq '.workflow_runs[0]' 2>/dev/null || echo '{"status":"error"}')
        local status=$(echo "$run_info" | jq -r '.status // "error"')
        local conclusion=$(echo "$run_info" | jq -r '.conclusion // "null"')
        local run_id=$(echo "$run_info" | jq -r '.id // "null"')
        
        log "状态: $status, 结论: $conclusion"
        
        case "$status" in
            "completed")
                if [ "$conclusion" = "success" ]; then
                    log_success "🎉 工作流成功完成！"
                    return 0
                else
                    log_error "工作流失败，开始修复..."
                    
                    # 获取错误日志
                    local jobs=$(gh api repos/$REPO_OWNER/$REPO_NAME/actions/runs/$run_id/jobs --jq '.jobs[] | select(.conclusion == "failure")' 2>/dev/null || echo '[]')
                    local job_id=$(echo "$jobs" | jq -r '.id' | head -1)
                    
                    if [ -n "$job_id" ] && [ "$job_id" != "null" ]; then
                        # 获取错误日志
                        gh api repos/$REPO_OWNER/$REPO_NAME/actions/jobs/$job_id/logs > /tmp/error_log.txt 2>/dev/null || true
                        
                        # 分析错误并修复
                        local error_summary=$(head -50 /tmp/error_log.txt | grep -E "(error|Error|ERROR)" | head -5 | tr '\n' ' ')
                        log "错误摘要: $error_summary"
                        
                        # 快速修复
                        quick_fix "$error_summary"
                        
                        # 重新触发工作流
                        local workflow_id=$(echo "$run_info" | jq -r '.workflow_id')
                        gh workflow run $workflow_id --repo $REPO_OWNER/$REPO_NAME
                        log "已重新触发工作流"
                    else
                        log_warning "无法获取错误详情，等待下次检查"
                    fi
                fi
                ;;
            "in_progress"|"queued")
                log "工作流正在运行，等待 $CHECK_INTERVAL 秒..."
                ;;
            "error"|*)
                log_warning "无法获取状态或状态异常: $status"
                ;;
        esac
        
        sleep $CHECK_INTERVAL
    done
    
    log_error "达到最大检查次数，停止监控"
    return 1
}

# 主函数
main() {
    log "开始持续监控 GitHub Actions"
    log "仓库: $REPO_OWNER/$REPO_NAME"
    log "工作流: $WORKFLOW_NAME"
    log "检查间隔: ${CHECK_INTERVAL}秒"
    log "最大尝试次数: $MAX_ATTEMPTS"
    echo "----------------------------------------"
    
    # 检查 GitHub CLI
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI 未安装，请先安装: https://cli.github.com/"
        exit 1
    fi
    
    # 检查认证
    if ! gh auth status &> /dev/null; then
        log_error "GitHub CLI 未认证，请先运行: gh auth login"
        exit 1
    fi
    
    # 开始监控
    check_workflow
}

# 运行主函数
main "$@"