#!/bin/bash

# 简单的构建状态检查脚本
# 使用GitHub API检查最新的构建状态

REPO="${GITHUB_REPOSITORY:-SourceDive/jdk}"
BRANCH="${GITHUB_REF_NAME:-$(git branch --show-current 2>/dev/null || echo 'main')}"
WORKFLOW="build-jdk.yml"

echo "=== JDK构建状态检查 ==="
echo "仓库: $REPO"
echo "分支: $BRANCH"
echo "工作流: $WORKFLOW"
echo ""

# 使用GitHub CLI检查（如果可用）
if command -v gh &> /dev/null && gh auth status &> /dev/null; then
    echo "使用GitHub CLI检查构建状态..."
    echo ""
    
    # 获取最新运行
    LATEST_RUN=$(gh run list --workflow="$WORKFLOW" --branch="$BRANCH" --limit=1 --json status,conclusion,databaseId,url,createdAt 2>/dev/null)
    
    if [ -z "$LATEST_RUN" ] || [ "$LATEST_RUN" = "[]" ]; then
        echo "⚠️  未找到构建运行"
        echo "触发构建: git push"
        exit 0
    fi
    
    STATUS=$(echo "$LATEST_RUN" | jq -r '.[0].status' 2>/dev/null)
    CONCLUSION=$(echo "$LATEST_RUN" | jq -r '.[0].conclusion // "N/A"' 2>/dev/null)
    RUN_ID=$(echo "$LATEST_RUN" | jq -r '.[0].databaseId' 2>/dev/null)
    URL=$(echo "$LATEST_RUN" | jq -r '.[0].url' 2>/dev/null)
    CREATED=$(echo "$LATEST_RUN" | jq -r '.[0].createdAt' 2>/dev/null)
    
    echo "运行ID: $RUN_ID"
    echo "创建时间: $CREATED"
    echo "状态: $STATUS"
    echo "结论: $CONCLUSION"
    echo "URL: $URL"
    echo ""
    
    case "$STATUS" in
        "completed")
            case "$CONCLUSION" in
                "success")
                    echo "✅ 构建成功！"
                    exit 0
                    ;;
                "failure")
                    echo "❌ 构建失败"
                    echo "查看详细日志: $URL"
                    exit 1
                    ;;
                "cancelled")
                    echo "⚠️  构建被取消"
                    exit 1
                    ;;
                *)
                    echo "⚠️  构建完成，结论: $CONCLUSION"
                    exit 1
                    ;;
            esac
            ;;
        "in_progress")
            echo "⏳ 构建进行中..."
            echo "实时查看: $URL"
            exit 2  # 返回2表示进行中
            ;;
        "queued")
            echo "⏳ 构建排队中..."
            exit 2
            ;;
        *)
            echo "⚠️  未知状态: $STATUS"
            exit 1
            ;;
    esac
else
    echo "⚠️  GitHub CLI未安装或未认证"
    echo ""
    echo "安装GitHub CLI:"
    echo "  https://cli.github.com/"
    echo ""
    echo "或者使用GitHub网页查看:"
    echo "  https://github.com/$REPO/actions"
    exit 1
fi
