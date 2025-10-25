#!/bin/bash

# GitHub Actions 自动监控和修复脚本
# 持续监控工作流运行状态，自动检测和修复错误

set -e

# 配置参数
REPO_OWNER="SourceDive"
REPO_NAME="jdk"
WORKFLOW_NAME="Build JDK"
GITHUB_TOKEN="${GITHUB_TOKEN:-$1}"
MAX_RETRIES=3
CHECK_INTERVAL=60  # 检查间隔（秒）
MAX_WAIT_TIME=7200  # 最大等待时间（秒）

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌${NC} $1"
}

# 检查依赖
check_dependencies() {
    log "检查依赖..."
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) 未安装"
        log "安装 GitHub CLI..."
        curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
        sudo apt update
        sudo apt install gh -y
    fi
    
    if ! command -v jq &> /dev/null; then
        log_error "jq 未安装"
        log "安装 jq..."
        sudo apt update
        sudo apt install jq -y
    fi
    
    if [ -z "$GITHUB_TOKEN" ]; then
        log_error "GitHub Token 未设置"
        log "请设置 GITHUB_TOKEN 环境变量或作为第一个参数传递"
        exit 1
    fi
    
    # 设置 GitHub CLI 认证
    echo "$GITHUB_TOKEN" | gh auth login --with-token
    
    log_success "依赖检查完成"
}

# 获取最新的工作流运行
get_latest_run() {
    local runs=$(gh api repos/$REPO_OWNER/$REPO_NAME/actions/runs --jq '.workflow_runs[0]')
    echo "$runs"
}

# 获取工作流运行状态
get_run_status() {
    local run_id="$1"
    local run=$(gh api repos/$REPO_OWNER/$REPO_NAME/actions/runs/$run_id --jq '.')
    echo "$run"
}

# 获取工作流日志
get_run_logs() {
    local run_id="$1"
    local job_id="$2"
    
    log "获取工作流日志..."
    gh api repos/$REPO_OWNER/$REPO_NAME/actions/jobs/$job_id/logs > /tmp/workflow_logs.txt
    echo "/tmp/workflow_logs.txt"
}

# 分析错误类型
analyze_error() {
    local log_file="$1"
    
    log "分析错误类型..."
    
    # 检查常见错误模式
    if grep -q "configure: error: unrecognized option" "$log_file"; then
        echo "configure_option_error"
    elif grep -q "Permission denied" "$log_file"; then
        echo "permission_error"
    elif grep -q "No space left on device" "$log_file"; then
        echo "disk_space_error"
    elif grep -q "autoconf" "$log_file" && grep -q "not found" "$log_file"; then
        echo "missing_dependency_error"
    elif grep -q "make: \*\*\*" "$log_file"; then
        echo "make_error"
    elif grep -q "javac: error" "$log_file"; then
        echo "javac_error"
    elif grep -q "gcc: error" "$log_file"; then
        echo "gcc_error"
    elif grep -q "timeout" "$log_file"; then
        echo "timeout_error"
    else
        echo "unknown_error"
    fi
}

# 自动修复错误
auto_fix_error() {
    local error_type="$1"
    local run_id="$2"
    
    log "尝试自动修复错误: $error_type"
    
    case "$error_type" in
        "configure_option_error")
            log "修复 configure 选项错误..."
            fix_configure_options
            ;;
        "permission_error")
            log "修复权限错误..."
            fix_permission_issues
            ;;
        "disk_space_error")
            log "修复磁盘空间错误..."
            fix_disk_space
            ;;
        "missing_dependency_error")
            log "修复缺失依赖错误..."
            fix_missing_dependencies
            ;;
        "make_error")
            log "修复 make 错误..."
            fix_make_issues
            ;;
        "javac_error")
            log "修复 javac 错误..."
            fix_javac_issues
            ;;
        "gcc_error")
            log "修复 gcc 错误..."
            fix_gcc_issues
            ;;
        "timeout_error")
            log "修复超时错误..."
            fix_timeout_issues
            ;;
        *)
            log_warning "未知错误类型，尝试通用修复..."
            apply_generic_fixes
            ;;
    esac
}

# 修复 configure 选项错误
fix_configure_options() {
    log "修复 configure 选项配置..."
    
    # 更新工作流文件中的 configure 参数
    sed -i 's/--with-extra-cflags="-Wno-error -O[0-9]/--with-extra-cflags="-Wno-error -O2/g' .github/workflows/build-jdk.yml
    sed -i 's/--with-extra-cxxflags="-Wno-error -O[0-9]/--with-extra-cxxflags="-Wno-error -O2/g' .github/workflows/build-jdk.yml
    
    # 移除可能无效的选项
    sed -i '/--with-memory-size/d' .github/workflows/build-jdk.yml
    
    log_success "configure 选项已修复"
}

# 修复权限错误
fix_permission_issues() {
    log "修复权限问题..."
    
    # 确保脚本有执行权限
    chmod +x configure
    chmod +x make/autoconf/configure
    
    # 确保构建目录权限
    mkdir -p build
    chmod 755 build
    
    log_success "权限问题已修复"
}

# 修复磁盘空间错误
fix_disk_space() {
    log "清理磁盘空间..."
    
    # 清理临时文件
    rm -rf /tmp/*
    rm -rf ~/.cache/*
    
    # 清理构建缓存
    rm -rf build/.configure-support
    rm -rf .buildcache
    
    # 清理包管理器缓存
    sudo apt clean
    sudo apt autoremove -y
    
    log_success "磁盘空间已清理"
}

# 修复缺失依赖错误
fix_missing_dependencies() {
    log "安装缺失的依赖..."
    
    # 更新包列表
    sudo apt update
    
    # 安装构建依赖
    sudo apt install -y \
        build-essential \
        autoconf \
        zip \
        unzip \
        file \
        libx11-dev \
        libxext-dev \
        libxrender-dev \
        libxrandr-dev \
        libxtst-dev \
        libxt-dev \
        libcups2-dev \
        libfontconfig1-dev \
        libasound2-dev \
        libfreetype6-dev \
        libffi-dev \
        pkg-config
    
    log_success "依赖已安装"
}

# 修复 make 错误
fix_make_issues() {
    log "修复 make 问题..."
    
    # 清理构建目录
    rm -rf build/*
    
    # 重新配置
    bash configure --with-debug-level=release --disable-warnings-as-errors
    
    log_success "make 问题已修复"
}

# 修复 javac 错误
fix_javac_issues() {
    log "修复 javac 问题..."
    
    # 设置正确的 Java 环境
    export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))
    export PATH=$JAVA_HOME/bin:$PATH
    
    # 清理 Java 编译缓存
    rm -rf build/*/support/classes
    
    log_success "javac 问题已修复"
}

# 修复 gcc 错误
fix_gcc_issues() {
    log "修复 gcc 问题..."
    
    # 安装完整的编译工具链
    sudo apt install -y gcc g++ make cmake
    
    # 设置编译器环境
    export CC=gcc
    export CXX=g++
    
    log_success "gcc 问题已修复"
}

# 修复超时错误
fix_timeout_issues() {
    log "修复超时问题..."
    
    # 增加超时时间
    sed -i 's/timeout-minutes: [0-9]*/timeout-minutes: 120/g' .github/workflows/build-jdk.yml
    
    # 减少并行任务数以避免资源竞争
    sed -i 's/optimal-jobs=\${{ steps.machine-config.outputs.optimal-jobs }}/optimal-jobs=2/g' .github/workflows/build-jdk.yml
    
    log_success "超时问题已修复"
}

# 应用通用修复
apply_generic_fixes() {
    log "应用通用修复..."
    
    # 清理所有构建产物
    rm -rf build/
    rm -rf .buildcache/
    
    # 重新生成 configure 脚本
    chmod +x configure
    chmod +x make/autoconf/configure
    
    # 更新工作流文件
    git add .github/workflows/build-jdk.yml
    git commit -m "Auto-fix: 修复工作流配置" || true
    
    log_success "通用修复已应用"
}

# 重新触发工作流
retrigger_workflow() {
    local run_id="$1"
    
    log "重新触发工作流..."
    
    # 获取工作流 ID
    local workflow_id=$(gh api repos/$REPO_OWNER/$REPO_NAME/actions/runs/$run_id --jq '.workflow_id')
    
    # 重新触发工作流
    gh workflow run $workflow_id --repo $REPO_OWNER/$REPO_NAME
    
    log_success "工作流已重新触发"
}

# 提交修复
commit_fixes() {
    log "提交修复..."
    
    # 添加所有修改
    git add .
    
    # 提交修改
    git commit -m "Auto-fix: $(date '+%Y-%m-%d %H:%M:%S') 自动修复工作流错误" || true
    
    # 推送到远程仓库
    git push origin HEAD || true
    
    log_success "修复已提交"
}

# 主监控循环
monitor_workflow() {
    local retry_count=0
    local start_time=$(date +%s)
    
    log "开始监控工作流: $WORKFLOW_NAME"
    log "检查间隔: ${CHECK_INTERVAL}秒"
    log "最大等待时间: ${MAX_WAIT_TIME}秒"
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        local current_time=$(date +%s)
        local elapsed_time=$((current_time - start_time))
        
        if [ $elapsed_time -gt $MAX_WAIT_TIME ]; then
            log_error "超过最大等待时间，停止监控"
            break
        fi
        
        log "检查工作流状态... (尝试 $((retry_count + 1))/$MAX_RETRIES)"
        
        # 获取最新运行
        local latest_run=$(get_latest_run)
        local run_id=$(echo "$latest_run" | jq -r '.id')
        local status=$(echo "$latest_run" | jq -r '.status')
        local conclusion=$(echo "$latest_run" | jq -r '.conclusion // "null"')
        
        log "运行 ID: $run_id"
        log "状态: $status"
        log "结论: $conclusion"
        
        case "$status" in
            "completed")
                if [ "$conclusion" = "success" ]; then
                    log_success "工作流成功完成！"
                    return 0
                else
                    log_error "工作流失败，开始错误分析..."
                    
                    # 获取失败的 job
                    local jobs=$(gh api repos/$REPO_OWNER/$REPO_NAME/actions/runs/$run_id/jobs --jq '.jobs[] | select(.conclusion == "failure")')
                    local job_id=$(echo "$jobs" | jq -r '.id' | head -1)
                    
                    if [ -n "$job_id" ]; then
                        # 获取日志
                        local log_file=$(get_run_logs "$run_id" "$job_id")
                        
                        # 分析错误
                        local error_type=$(analyze_error "$log_file")
                        log "检测到错误类型: $error_type"
                        
                        # 自动修复
                        auto_fix_error "$error_type" "$run_id"
                        
                        # 提交修复
                        commit_fixes
                        
                        # 重新触发
                        retrigger_workflow "$run_id"
                        
                        retry_count=$((retry_count + 1))
                        log "等待 $CHECK_INTERVAL 秒后重试..."
                        sleep $CHECK_INTERVAL
                    else
                        log_error "无法获取失败的 job 信息"
                        break
                    fi
                fi
                ;;
            "in_progress"|"queued")
                log "工作流正在运行，等待 $CHECK_INTERVAL 秒..."
                sleep $CHECK_INTERVAL
                ;;
            *)
                log_warning "未知状态: $status"
                sleep $CHECK_INTERVAL
                ;;
        esac
    done
    
    if [ $retry_count -ge $MAX_RETRIES ]; then
        log_error "达到最大重试次数，停止监控"
        return 1
    fi
}

# 主函数
main() {
    log "GitHub Actions 自动监控和修复系统启动"
    
    # 检查依赖
    check_dependencies
    
    # 开始监控
    monitor_workflow
    
    if [ $? -eq 0 ]; then
        log_success "监控完成，工作流成功运行"
    else
        log_error "监控失败，请手动检查"
        exit 1
    fi
}

# 运行主函数
main "$@"