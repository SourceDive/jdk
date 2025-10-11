#!/bin/bash

# JDK 12 开发环境脚本

echo "=== JDK 12 开发环境 ==="

# 检查Docker是否运行
if ! docker info &> /dev/null; then
    echo "错误: Docker 未运行，请启动 Docker"
    exit 1
fi

echo "启动JDK 12开发环境..."
echo "在容器中，你可以："
echo "  1. 运行 './configure --with-boot-jdk=/usr/lib/jvm/java-11-openjdk-amd64' 配置编译环境"
echo "  2. 运行 'make images' 编译JDK"
echo "  3. 使用 'make test' 运行测试"
echo "  4. 使用 'make clean' 清理编译结果"
echo ""

# 启动交互式容器
docker run -it --rm \
  --name jdk12-dev \
  -v "$(pwd)":/jdk \
  -v "$(pwd)/build":/jdk/build \
  -v "$(pwd)/docker_compiled_jdk":/jdk/compiled \
  -w /jdk \
  -e JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
  ubuntu:18.04 \
  bash -c "
    echo '安装编译依赖...' &&
    apt-get update && apt-get install -y \
      build-essential autoconf libx11-dev libxext-dev libxrender-dev \
      libxtst-dev libxt-dev libxrandr-dev libasound2-dev libcups2-dev \
      libfreetype6-dev libfontconfig1-dev libgtk-3-dev \
      unzip zip wget curl git mercurial openjdk-11-jdk &&
    echo '环境准备完成！' &&
    echo '当前目录: \$(pwd)' &&
    echo '可用命令: configure, make, make images, make test, make clean' &&
    bash
  "

