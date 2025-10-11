#!/bin/bash

# JDK 12 源码阅读环境启动脚本

set -e

echo "=== JDK 12 源码阅读环境 ==="

# 检查Docker是否运行
if ! docker info &> /dev/null; then
    echo "❌ Docker 未运行，请启动 Docker"
    exit 1
fi

# 检查Docker Compose是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

# 创建必要的目录
mkdir -p build docker_compiled_jdk

echo "🚀 启动JDK 12源码阅读环境..."
echo ""
echo "环境特点："
echo "  ✅ 支持UTF-8编码（可以添加中文注释）"
echo "  ✅ 源码双向同步（本地修改实时生效）"
echo "  ✅ 编译结果持久化"
echo "  ✅ 交互式开发环境"
echo ""

# 启动Docker Compose环境
docker-compose up --build

echo ""
echo "🎉 环境启动完成！"
echo ""
echo "使用说明："
echo "  1. 源码位置: ./src/"
echo "  2. 编译结果: ./docker_compiled_jdk/"
echo "  3. 重新启动: ./start-dev.sh"
echo "  4. 停止环境: docker-compose down"

