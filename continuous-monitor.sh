#!/bin/bash

# 持续监控JDK构建直到成功
# 每30秒检查一次构建状态，直到构建成功或失败

set -e

REPO="${GITHUB_REPOSITORY:-SourceDive/jdk}"
BRANCH="${GITHUB_REF_NAME:-$(git branch --show-current 2>/dev/null || echo 'main')}"
WORKFLOW="build-jdk.yml"
CHECK_INTERVAL=30  # 检查间隔（秒）
MAX_WAIT_TIME=21600  # 最大等待时间（6小时）

echo "=== JDK构建持续监控 ==="
echo "仓库: $REPO"
echo "分支: $BRANCH"
echo "检查间隔: ${CHECK_INTERVAL}秒"
echo "最大等待时间: ${MAX_WAIT_TIME}秒 ($(($MAX_WAIT_TIME / 3600))小时)"
echo ""
echo "开始监控，按Ctrl+C停止..."
echo ""

START_TIME=$(date +%s)
CHECK_COUNT=0

# 检查GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "❌ 错误: GitHub CLI (gh) 未安装"
    echo "请安装: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "❌ 错误: GitHub CLI未认证"
    echo "请运行: gh auth login"
    exit 1
fi

# 获取最新运行状态
get_status() {
    local run_info=$(gh run list --workflow="$WORKFLOW" --branch="$BRANCH" --limit=1 --json status,conclusion,databaseId,url,createdAt 2>/dev/null)
    
    if [ -z "$run_info" ] || [ "$run_info" = "[]" ]; then
        echo "null"
        return
    fi
    
    echo "$run_info" | jq -r '.[0] | "\(.status)|\(.conclusion // "N/A")|\(.databaseId)|\(.url)|\(.createdAt)"' 2>/dev/null || echo "null"
}

# 主监控循环
while true; do
    CHECK_COUNT=$((CHECK_COUNT + 1))
    ELAPSED=$(($(date +%s) - START_TIME))
    ELAPSED_MIN=$((ELAPSED / 60))
    ELAPSED_SEC=$((ELAPSED % 60))
    
    # 检查是否超过最大等待时间
    if [ $ELAPSED -gt $MAX_WAIT_TIME ]; then
        echo ""
        echo "❌ 超过最大等待时间 ($(($MAX_WAIT_TIME / 3600))小时)，停止监控"
        exit 1
    fi
    
    echo "[$(date '+%H:%M:%S')] 检查 #$CHECK_COUNT (已等待: ${ELAPSED_MIN}分${ELAPSED_SEC}秒)"
    
    STATUS_INFO=$(get_status)
    
    if [ "$STATUS_INFO" = "null" ]; then
        echo "  ⚠️  未找到构建运行"
        echo "  💡 提示: 可能需要触发新的构建"
        sleep $CHECK_INTERVAL
        continue
    fi
    
    IFS='|' read -r status conclusion run_id url created <<< "$STATUS_INFO"
    
    echo "  运行ID: $run_id"
    echo "  状态: $status"
    echo "  结论: $conclusion"
    
    case "$status" in
        "completed")
            case "$conclusion" in
                "success")
                    echo ""
                    echo "🎉🎉🎉 构建成功！ 🎉🎉🎉"
                    echo ""
                    echo "运行ID: $run_id"
                    echo "URL: $url"
                    echo "总耗时: ${ELAPSED_MIN}分${ELAPSED_SEC}秒"
                    echo ""
                    echo "✅ 监控完成：构建成功通过！"
                    exit 0
                    ;;
                "failure")
                    echo ""
                    echo "❌ 构建失败"
                    echo ""
                    echo "运行ID: $run_id"
                    echo "查看日志: $url"
                    echo ""
                    echo "❌ 监控完成：构建失败"
                    exit 1
                    ;;
                "cancelled")
                    echo ""
                    echo "⚠️  构建被取消"
                    echo "运行ID: $run_id"
                    echo "URL: $url"
                    exit 1
                    ;;
                *)
                    echo ""
                    echo "⚠️  构建完成，但结论未知: $conclusion"
                    echo "运行ID: $run_id"
                    echo "URL: $url"
                    exit 1
                    ;;
            esac
            ;;
        "in_progress")
            echo "  ⏳ 构建进行中..."
            echo "  🔗 实时查看: $url"
            ;;
        "queued")
            echo "  ⏳ 构建排队中..."
            echo "  🔗 查看: $url"
            ;;
        *)
            echo "  ⚠️  未知状态: $status"
            ;;
    esac
    
    echo ""
    sleep $CHECK_INTERVAL
done
