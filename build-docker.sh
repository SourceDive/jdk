#!/bin/bash

# JDK 12 Docker 编译脚本

set -e

echo "=== JDK 12 Docker 编译环境 ==="

# 检查Docker是否安装
if ! command -v docker &> /dev/null; then
    echo "错误: Docker 未安装，请先安装 Docker"
    exit 1
fi

# 检查Docker Compose是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "错误: Docker Compose 未安装，请先安装 Docker Compose"
    exit 1
fi

# 创建必要的目录
mkdir -p build docker_compiled_jdk

echo "1. 构建Docker镜像..."
docker-compose build

echo "2. 开始编译JDK..."
docker-compose up

echo "3. 编译完成！"
echo "编译结果位置: ./docker_compiled_jdk/"
echo ""

# 检查编译结果
if [ -d "./docker_compiled_jdk/bin" ]; then
    echo "✅ 编译成功！"
    echo "JDK 位置: $(pwd)/docker_compiled_jdk"
    echo ""
    echo "使用方法:"
    echo "  export JAVA_HOME=$(pwd)/docker_compiled_jdk"
    echo "  export PATH=\$JAVA_HOME/bin:\$PATH"
    echo ""
    echo "验证编译结果:"
    echo "  \$JAVA_HOME/bin/java -version"
else
    echo "❌ 编译失败，请检查错误信息"
    exit 1
fi

