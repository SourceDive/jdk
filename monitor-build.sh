#!/bin/bash

# JDK构建监控脚本
# 持续监控GitHub Actions构建状态，直到成功为止

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
REPO="${GITHUB_REPOSITORY:-SourceDive/jdk}"
BRANCH="${GITHUB_REF_NAME:-$(git branch --show-current 2>/dev/null || echo 'main')}"
CHECK_INTERVAL=30  # 检查间隔（秒）
MAX_WAIT_TIME=7200  # 最大等待时间（秒），2小时
START_TIME=$(date +%s)

# 检查GitHub CLI是否可用
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}⚠️  GitHub CLI (gh) 未安装，将使用GitHub API直接查询${NC}"
    USE_GH=false
else
    echo -e "${GREEN}✅ GitHub CLI 已安装${NC}"
    USE_GH=true
fi

echo -e "${BLUE}=== JDK构建监控脚本 ===${NC}"
echo "仓库: $REPO"
echo "分支: $BRANCH"
echo "检查间隔: ${CHECK_INTERVAL}秒"
echo "最大等待时间: ${MAX_WAIT_TIME}秒"
echo ""

# 获取最新工作流运行ID
get_latest_run_id() {
    if [ "$USE_GH" = true ]; then
        gh run list --workflow=build-jdk.yml --branch="$BRANCH" --limit=1 --json databaseId --jq '.[0].databaseId' 2>/dev/null || echo ""
    else
        # 使用GitHub API
        curl -s -H "Authorization: token ${GITHUB_TOKEN:-}" \
            "https://api.github.com/repos/$REPO/actions/workflows/build-jdk.yml/runs?branch=$BRANCH&per_page=1" \
            | grep -o '"id":[0-9]*' | head -1 | cut -d: -f2 || echo ""
    fi
}

# 获取运行状态
get_run_status() {
    local run_id=$1
    if [ "$USE_GH" = true ]; then
        gh run view "$run_id" --json status,conclusion --jq '{status: .status, conclusion: .conclusion}' 2>/dev/null || echo '{"status":"unknown","conclusion":"unknown"}'
    else
        curl -s -H "Authorization: token ${GITHUB_TOKEN:-}" \
            "https://api.github.com/repos/$REPO/actions/runs/$run_id" \
            | grep -oE '"status":"[^"]*"|"conclusion":"[^"]*"' | sed 's/"//g' | sed 's/status://' | sed 's/conclusion://' || echo "status:unknown conclusion:unknown"
    fi
}

# 获取运行URL
get_run_url() {
    local run_id=$1
    if [ "$USE_GH" = true ]; then
        gh run view "$run_id" --json url --jq '.url' 2>/dev/null || echo ""
    else
        echo "https://github.com/$REPO/actions/runs/$run_id"
    fi
}

# 显示运行日志（最后50行）
show_run_logs() {
    local run_id=$1
    if [ "$USE_GH" = true ]; then
        echo -e "${BLUE}=== 最近的构建日志 ===${NC}"
        gh run view "$run_id" --log-failed 2>/dev/null | tail -50 || echo "无法获取日志"
    fi
}

# 等待新的构建开始
wait_for_new_run() {
    echo -e "${YELLOW}等待新的构建开始...${NC}"
    local last_run_id=""
    local check_count=0
    
    while [ $check_count -lt 20 ]; do
        local current_run_id=$(get_latest_run_id)
        
        if [ -n "$current_run_id" ] && [ "$current_run_id" != "$last_run_id" ]; then
            echo -e "${GREEN}✅ 检测到新的构建: $current_run_id${NC}"
            echo "$current_run_id"
            return 0
        fi
        
        sleep 10
        check_count=$((check_count + 1))
        echo -n "."
    done
    
    echo -e "${RED}❌ 未检测到新的构建${NC}"
    return 1
}

# 监控构建状态
monitor_run() {
    local run_id=$1
    local run_url=$(get_run_url "$run_id")
    
    echo -e "${BLUE}监控构建: $run_id${NC}"
    echo "构建URL: $run_url"
    echo ""
    
    while true; do
        local elapsed=$(($(date +%s) - START_TIME))
        
        # 检查是否超过最大等待时间
        if [ $elapsed -gt $MAX_WAIT_TIME ]; then
            echo -e "${RED}❌ 超过最大等待时间 (${MAX_WAIT_TIME}秒)，停止监控${NC}"
            return 1
        fi
        
        # 获取运行状态
        local status_info=$(get_run_status "$run_id")
        local status=$(echo "$status_info" | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        local conclusion=$(echo "$status_info" | grep -o '"conclusion":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
        
        # 显示状态
        local time_str=$(date '+%Y-%m-%d %H:%M:%S')
        local elapsed_min=$((elapsed / 60))
        local elapsed_sec=$((elapsed % 60))
        
        echo -e "${BLUE}[$time_str] 已等待: ${elapsed_min}分${elapsed_sec}秒${NC}"
        echo "状态: $status"
        echo "结论: $conclusion"
        
        # 检查状态
        case "$status" in
            "completed")
                case "$conclusion" in
                    "success")
                        echo -e "${GREEN}✅ 构建成功完成！${NC}"
                        show_run_logs "$run_id"
                        return 0
                        ;;
                    "failure")
                        echo -e "${RED}❌ 构建失败${NC}"
                        show_run_logs "$run_id"
                        return 1
                        ;;
                    "cancelled")
                        echo -e "${YELLOW}⚠️ 构建被取消${NC}"
                        return 1
                        ;;
                    *)
                        echo -e "${YELLOW}⚠️ 构建完成，但结论未知: $conclusion${NC}"
                        show_run_logs "$run_id"
                        return 1
                        ;;
                esac
                ;;
            "in_progress"|"queued")
                echo -e "${YELLOW}⏳ 构建进行中...${NC}"
                ;;
            *)
                echo -e "${YELLOW}⚠️ 未知状态: $status${NC}"
                ;;
        esac
        
        echo ""
        sleep $CHECK_INTERVAL
    done
}

# 主函数
main() {
    # 检查是否提供了运行ID
    if [ -n "$1" ]; then
        RUN_ID=$1
        echo -e "${BLUE}使用提供的运行ID: $RUN_ID${NC}"
    else
        # 等待新的构建
        RUN_ID=$(wait_for_new_run)
        if [ -z "$RUN_ID" ]; then
            echo -e "${RED}❌ 无法获取构建运行ID${NC}"
            exit 1
        fi
    fi
    
    # 监控构建
    if monitor_run "$RUN_ID"; then
        echo -e "${GREEN}✅ 监控完成：构建成功${NC}"
        exit 0
    else
        echo -e "${RED}❌ 监控完成：构建失败或超时${NC}"
        exit 1
    fi
}

# 运行主函数
main "$@"
