#!/bin/bash

# 启动 GitHub Actions 自动监控和修复系统

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                GitHub Actions 自动监控系统                    ║"
echo "║                                                              ║"
echo "║  🎯 功能: 持续监控工作流运行状态                              ║"
echo "║  🔧 自动修复: 检测并修复常见错误                              ║"
echo "║  🔄 自动重试: 修复后自动重新触发工作流                        ║"
echo "║  📊 实时监控: 每30秒检查一次状态                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 检查 GitHub CLI
if ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}⚠️  GitHub CLI 未安装，正在安装...${NC}"
    
    # 检测操作系统
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux 安装
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh -y
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS 安装
        if command -v brew &> /dev/null; then
            brew install gh
        else
            echo "请先安装 Homebrew 或手动安装 GitHub CLI"
            exit 1
        fi
    else
        echo "不支持的操作系统，请手动安装 GitHub CLI"
        exit 1
    fi
fi

# 检查认证
if ! gh auth status &> /dev/null; then
    echo -e "${YELLOW}⚠️  GitHub CLI 未认证，请先登录...${NC}"
    gh auth login
fi

# 检查 jq
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq 未安装，正在安装...${NC}"
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        sudo apt update && sudo apt install jq -y
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        brew install jq
    fi
fi

# 设置权限
chmod +x continuous-monitor.sh
chmod +x monitor-and-fix.sh

echo -e "${GREEN}✅ 环境检查完成${NC}"
echo ""

# 选择监控模式
echo "请选择监控模式："
echo "1. 持续监控模式 (推荐) - 每30秒检查一次，自动修复错误"
echo "2. 完整监控模式 - 详细的错误分析和修复"
echo "3. 仅监控模式 - 只监控不修复"
echo ""

read -p "请输入选择 (1-3): " choice

case $choice in
    1)
        echo -e "${GREEN}🚀 启动持续监控模式...${NC}"
        echo "按 Ctrl+C 停止监控"
        echo ""
        ./continuous-monitor.sh
        ;;
    2)
        echo -e "${GREEN}🚀 启动完整监控模式...${NC}"
        echo "按 Ctrl+C 停止监控"
        echo ""
        ./monitor-and-fix.sh
        ;;
    3)
        echo -e "${GREEN}🚀 启动仅监控模式...${NC}"
        echo "按 Ctrl+C 停止监控"
        echo ""
        # 修改脚本为仅监控模式
        sed 's/quick_fix/# quick_fix/g' continuous-monitor.sh | sed 's/quick_fix/echo "仅监控模式，跳过修复"/g' > monitor-only.sh
        chmod +x monitor-only.sh
        ./monitor-only.sh
        ;;
    *)
        echo -e "${YELLOW}无效选择，使用默认的持续监控模式${NC}"
        ./continuous-monitor.sh
        ;;
esac