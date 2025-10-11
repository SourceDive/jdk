# OpenJDK 12 源码阅读和编译环境
FROM ubuntu:18.04

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV JAVA_TOOL_OPTIONS=-Dfile.encoding=UTF-8

# 安装必要的工具和依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    autoconf \
    libx11-dev \
    libxext-dev \
    libxrender-dev \
    libxtst-dev \
    libxt-dev \
    libxrandr-dev \
    libasound2-dev \
    libcups2-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    libgtk-3-dev \
    libgconf-2-4 \
    libxss1 \
    libgconf2-dev \
    unzip \
    zip \
    wget \
    curl \
    git \
    mercurial \
    && rm -rf /var/lib/apt/lists/*

# 安装OpenJDK 11作为Boot JDK
RUN apt-get update && apt-get install -y openjdk-11-jdk && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /jdk

# 复制源码
COPY . /jdk/

# 设置JAVA_HOME
ENV JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64

# 配置编译环境
RUN bash configure --with-boot-jdk=$JAVA_HOME --with-debug-level=slowdebug

# 编译JDK
RUN make images

# 设置默认命令
CMD ["bash"]
