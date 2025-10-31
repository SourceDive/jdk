#!/bin/bash

# JDK构建持续监控和自动修复脚本
# 这个脚本会监控GitHub Actions构建，如果失败会自动触发修复

set -e

REPO="${GITHUB_REPOSITORY:-SourceDive/jdk}"
BRANCH="${GITHUB_REF_NAME:-$(git branch --show-current 2>/dev/null || echo 'main')}"
WORKFLOW_FILE=".github/workflows/build-jdk.yml"

echo "=== JDK构建监控和自动修复脚本 ==="
echo "仓库: $REPO"
echo "分支: $BRANCH"
echo ""

# 检查GitHub CLI
if ! command -v gh &> /dev/null; then
    echo "⚠️  警告: GitHub CLI (gh) 未安装"
    echo "请安装: https://cli.github.com/"
    exit 1
fi

# 检查是否已登录
if ! gh auth status &> /dev/null; then
    echo "⚠️  需要GitHub认证，请运行: gh auth login"
    exit 1
fi

# 触发新的构建
trigger_build() {
    echo "🚀 触发新的构建..."
    # 创建一个空提交来触发构建
    git config user.name "GitHub Actions Bot" || true
    git config user.email "actions@github.com" || true
    
    # 创建一个标记文件来触发构建
    touch .trigger-build-$(date +%s)
    git add .trigger-build-* 2>/dev/null || true
    
    # 如果没有变更，创建一个空提交
    if git diff --cached --quiet; then
        git commit --allow-empty -m "触发JDK构建 [$(date '+%Y-%m-%d %H:%M:%S')]" || true
    fi
    
    git push origin "$BRANCH" 2>/dev/null || echo "⚠️  无法推送，可能需要手动触发构建"
}

# 获取最新运行状态
get_latest_run_status() {
    local run_info=$(gh run list --workflow=build-jdk.yml --branch="$BRANCH" --limit=1 --json status,conclusion,databaseId,url 2>/dev/null)
    
    if [ -z "$run_info" ]; then
        echo "null"
        return
    fi
    
    echo "$run_info" | jq -r '.[0] | "\(.status)|\(.conclusion)|\(.databaseId)|\(.url)"' 2>/dev/null || echo "null"
}

# 监控构建
monitor_build() {
    local max_attempts=10
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        attempt=$((attempt + 1))
        echo ""
        echo "=== 检查 $attempt/$max_attempts ==="
        
        local status_info=$(get_latest_run_status)
        
        if [ "$status_info" = "null" ] || [ -z "$status_info" ]; then
            echo "⚠️  未找到构建运行"
            echo "触发新的构建..."
            trigger_build
            sleep 30
            continue
        fi
        
        IFS='|' read -r status conclusion run_id url <<< "$status_info"
        
        echo "运行ID: $run_id"
        echo "状态: $status"
        echo "结论: $conclusion"
        echo "URL: $url"
        
        case "$status" in
            "completed")
                case "$conclusion" in
                    "success")
                        echo "✅ 构建成功！"
                        return 0
                        ;;
                    "failure")
                        echo "❌ 构建失败"
                        echo "查看日志: $url"
                        return 1
                        ;;
                    "cancelled")
                        echo "⚠️  构建被取消"
                        return 1
                        ;;
                    *)
                        echo "⚠️  构建完成，结论: $conclusion"
                        return 1
                        ;;
                esac
                ;;
            "in_progress"|"queued")
                echo "⏳ 构建进行中，等待..."
                sleep 60
                ;;
            *)
                echo "⚠️  未知状态: $status"
                sleep 30
                ;;
        esac
    done
    
    echo "❌ 达到最大检查次数"
    return 1
}

# 主函数
main() {
    echo "开始监控构建..."
    
    # 先触发一个构建
    trigger_build
    sleep 10
    
    # 监控构建
    if monitor_build; then
        echo ""
        echo "✅ 构建监控完成：构建成功"
        exit 0
    else
        echo ""
        echo "❌ 构建监控完成：构建失败或超时"
        echo ""
        echo "可能的修复建议："
        echo "1. 检查构建日志中的具体错误"
        echo "2. 检查依赖是否已正确安装"
        echo "3. 检查磁盘空间是否充足"
        echo "4. 检查超时设置是否合理"
        exit 1
    fi
}

main "$@"
