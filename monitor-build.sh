#!/bin/bash

# JDK构建监控脚本
# 监听GitHub Actions构建状态直到成功

set -e

# 配置
REPO_OWNER="SourceDive"  # 替换为您的GitHub用户名或组织名
REPO_NAME="jdk-12"       # 替换为您的仓库名
BRANCH="cursor/download-jdk-compilation-artifacts-8976"
CHECK_INTERVAL=30        # 检查间隔（秒）
MAX_ATTEMPTS=20          # 最大检查次数
GITHUB_TOKEN=""          # GitHub Token（可选，用于提高API限制）

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# 检查依赖
check_dependencies() {
    log "检查依赖..."
    
    if ! command -v curl &> /dev/null; then
        error "curl 未安装，请先安装 curl"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        warning "jq 未安装，将使用基础JSON解析"
        JQ_AVAILABLE=false
    else
        JQ_AVAILABLE=true
    fi
    
    success "依赖检查完成"
}

# 获取最新工作流运行状态
get_workflow_status() {
    local api_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runs"
    local headers=""
    
    if [ -n "$GITHUB_TOKEN" ]; then
        headers="-H \"Authorization: token ${GITHUB_TOKEN}\""
    fi
    
    local response
    if [ "$JQ_AVAILABLE" = true ]; then
        response=$(curl -s $headers "$api_url?branch=${BRANCH}&per_page=1" | jq -r '.workflow_runs[0]')
        echo "$response"
    else
        response=$(curl -s $headers "$api_url?branch=${BRANCH}&per_page=1")
        echo "$response"
    fi
}

# 解析工作流状态
parse_workflow_status() {
    local response="$1"
    
    if [ "$JQ_AVAILABLE" = true ]; then
        local status=$(echo "$response" | jq -r '.status')
        local conclusion=$(echo "$response" | jq -r '.conclusion')
        local html_url=$(echo "$response" | jq -r '.html_url')
        local created_at=$(echo "$response" | jq -r '.created_at')
        local updated_at=$(echo "$response" | jq -r '.updated_at')
        
        echo "$status|$conclusion|$html_url|$created_at|$updated_at"
    else
        # 基础解析（不使用jq）
        local status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
        local conclusion=$(echo "$response" | grep -o '"conclusion":"[^"]*"' | cut -d'"' -f4)
        local html_url=$(echo "$response" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)
        
        echo "$status|$conclusion|$html_url|$(date)|$(date)"
    fi
}

# 触发工作流
trigger_workflow() {
    log "触发GitHub Actions工作流..."
    
    if [ -n "$GITHUB_TOKEN" ]; then
        local api_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/workflows/build-jdk.yml/dispatches"
        local payload='{"ref":"'${BRANCH}'","inputs":{"retry_count":"0"}}'
        
        curl -X POST \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "$api_url"
        
        if [ $? -eq 0 ]; then
            success "工作流已触发"
        else
            error "工作流触发失败"
            return 1
        fi
    else
        warning "未设置GITHUB_TOKEN，请手动触发工作流"
        warning "访问: https://github.com/${REPO_OWNER}/${REPO_NAME}/actions/workflows/build-jdk.yml"
        warning "点击 'Run workflow' 按钮"
        read -p "按回车键继续监控..."
    fi
}

# 监控工作流状态
monitor_workflow() {
    local attempt=1
    
    log "开始监控工作流状态..."
    log "仓库: ${REPO_OWNER}/${REPO_NAME}"
    log "分支: ${BRANCH}"
    log "检查间隔: ${CHECK_INTERVAL}秒"
    log "最大尝试次数: ${MAX_ATTEMPTS}"
    echo ""
    
    while [ $attempt -le $MAX_ATTEMPTS ]; do
        log "检查第 ${attempt}/${MAX_ATTEMPTS} 次..."
        
        local response=$(get_workflow_status)
        if [ $? -ne 0 ] || [ -z "$response" ]; then
            error "获取工作流状态失败"
            sleep $CHECK_INTERVAL
            ((attempt++))
            continue
        fi
        
        local status_info=$(parse_workflow_status "$response")
        IFS='|' read -r status conclusion html_url created_at updated_at <<< "$status_info"
        
        log "状态: $status"
        if [ -n "$conclusion" ] && [ "$conclusion" != "null" ]; then
            log "结论: $conclusion"
        fi
        log "链接: $html_url"
        log "创建时间: $created_at"
        log "更新时间: $updated_at"
        
        case "$status" in
            "completed")
                if [ "$conclusion" = "success" ]; then
                    success "🎉 构建成功完成！"
                    success "下载链接: $html_url"
                    return 0
                else
                    error "构建失败，结论: $conclusion"
                    error "查看详情: $html_url"
                    return 1
                fi
                ;;
            "in_progress"|"queued")
                log "构建进行中，等待 ${CHECK_INTERVAL} 秒后再次检查..."
                ;;
            "cancelled")
                error "构建被取消"
                return 1
                ;;
            *)
                warning "未知状态: $status"
                ;;
        esac
        
        sleep $CHECK_INTERVAL
        ((attempt++))
    done
    
    error "监控超时，已达到最大尝试次数"
    return 1
}

# 主函数
main() {
    echo "=== JDK构建监控脚本 ==="
    echo ""
    
    # 检查依赖
    check_dependencies
    
    # 询问是否触发工作流
    echo ""
    read -p "是否触发新的构建？(y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        trigger_workflow
        echo ""
    fi
    
    # 开始监控
    monitor_workflow
    
    if [ $? -eq 0 ]; then
        success "监控完成，构建成功！"
        exit 0
    else
        error "监控完成，构建失败或超时"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    echo "JDK构建监控脚本"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -h, --help     显示此帮助信息"
    echo "  -t, --token    设置GitHub Token"
    echo "  -o, --owner    设置仓库所有者 (默认: SourceDive)"
    echo "  -n, --name     设置仓库名称 (默认: jdk-12)"
    echo "  -b, --branch   设置分支名称 (默认: cursor/download-jdk-compilation-artifacts-8976)"
    echo "  -i, --interval 设置检查间隔秒数 (默认: 30)"
    echo "  -m, --max      设置最大检查次数 (默认: 20)"
    echo ""
    echo "环境变量:"
    echo "  GITHUB_TOKEN   GitHub访问令牌"
    echo ""
    echo "示例:"
    echo "  $0                                    # 使用默认设置"
    echo "  $0 -t your_token -o your_org -n your_repo  # 自定义设置"
    echo "  GITHUB_TOKEN=your_token $0            # 使用环境变量"
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -t|--token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -o|--owner)
            REPO_OWNER="$2"
            shift 2
            ;;
        -n|--name)
            REPO_NAME="$2"
            shift 2
            ;;
        -b|--branch)
            BRANCH="$2"
            shift 2
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -m|--max)
            MAX_ATTEMPTS="$2"
            shift 2
            ;;
        *)
            error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 运行主函数
main