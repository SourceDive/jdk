#!/bin/bash

# 快速检查JDK构建状态

set -e

# 配置
REPO_OWNER="SourceDive"
REPO_NAME="jdk-12"
BRANCH="cursor/download-jdk-compilation-artifacts-8976"

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

# 检查工作流状态
check_status() {
    log "检查构建状态..."
    
    local api_url="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runs"
    local response=$(curl -s "$api_url?branch=${BRANCH}&per_page=1")
    
    if [ $? -ne 0 ]; then
        error "无法连接到GitHub API"
        return 1
    fi
    
    # 解析状态
    local status=$(echo "$response" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
    local conclusion=$(echo "$response" | grep -o '"conclusion":"[^"]*"' | cut -d'"' -f4)
    local html_url=$(echo "$response" | grep -o '"html_url":"[^"]*"' | cut -d'"' -f4)
    local created_at=$(echo "$response" | grep -o '"created_at":"[^"]*"' | cut -d'"' -f4)
    
    echo ""
    echo "=== 构建状态 ==="
    echo "状态: $status"
    if [ -n "$conclusion" ] && [ "$conclusion" != "null" ]; then
        echo "结论: $conclusion"
    fi
    echo "创建时间: $created_at"
    echo "详情链接: $html_url"
    echo ""
    
    case "$status" in
        "completed")
            if [ "$conclusion" = "success" ]; then
                success "构建成功！可以下载产物了"
                echo ""
                echo "下载步骤："
                echo "1. 访问: $html_url"
                echo "2. 在 Artifacts 部分下载 jdk-build-artifacts-*"
                echo "3. 解压后设置 JAVA_HOME 环境变量"
                return 0
            else
                error "构建失败，结论: $conclusion"
                echo "查看详情: $html_url"
                return 1
            fi
            ;;
        "in_progress")
            warning "构建进行中..."
            echo "请稍后再检查"
            return 2
            ;;
        "queued")
            warning "构建排队中..."
            echo "请稍后再检查"
            return 2
            ;;
        *)
            warning "未知状态: $status"
            return 2
            ;;
    esac
}

# 触发构建
trigger_build() {
    log "触发新的构建..."
    
    # 检查是否有未提交的更改
    if [ -n "$(git status --porcelain)" ]; then
        warning "检测到未提交的更改，正在提交..."
        git add .
        git commit -m "触发JDK构建 - $(date '+%Y-%m-%d %H:%M:%S')"
    fi
    
    # 推送到远程仓库
    log "推送到远程仓库..."
    git push origin "$BRANCH"
    
    if [ $? -eq 0 ]; then
        success "已触发构建，请等待几分钟后再次检查"
    else
        error "推送失败，无法触发构建"
        return 1
    fi
}

# 主函数
main() {
    echo "=== JDK构建状态检查 ==="
    echo ""
    
    # 检查当前状态
    check_status
    local status_code=$?
    
    case $status_code in
        0)  # 成功
            exit 0
            ;;
        1)  # 失败
            echo ""
            read -p "构建失败，是否触发新的构建？(y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                trigger_build
            fi
            exit 1
            ;;
        2)  # 进行中
            echo ""
            read -p "构建进行中，是否继续监控？(y/N): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "开始监控..."
                while true; do
                    sleep 30
                    check_status
                    if [ $? -eq 0 ] || [ $? -eq 1 ]; then
                        break
                    fi
                done
            fi
            exit 2
            ;;
    esac
}

# 运行主函数
main "$@"