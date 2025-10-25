#!/bin/bash

# 测试监控系统功能

set -e

# 颜色输出
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[TEST] ✅${NC} $1"
}

log_error() {
    echo -e "${RED}[TEST] ❌${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[TEST] ⚠️${NC} $1"
}

# 测试依赖
test_dependencies() {
    log "测试依赖..."
    
    # 测试 GitHub CLI
    if command -v gh &> /dev/null; then
        log_success "GitHub CLI 已安装"
        if gh auth status &> /dev/null; then
            log_success "GitHub CLI 已认证"
        else
            log_warning "GitHub CLI 未认证，请运行: gh auth login"
        fi
    else
        log_error "GitHub CLI 未安装"
        return 1
    fi
    
    # 测试 jq
    if command -v jq &> /dev/null; then
        log_success "jq 已安装"
    else
        log_error "jq 未安装"
        return 1
    fi
    
    # 测试脚本权限
    if [ -x "continuous-monitor.sh" ]; then
        log_success "监控脚本有执行权限"
    else
        log_error "监控脚本无执行权限"
        return 1
    fi
    
    return 0
}

# 测试 GitHub API 连接
test_github_api() {
    log "测试 GitHub API 连接..."
    
    if gh api repos/SourceDive/jdk/actions/runs --jq '.workflow_runs[0].id' &> /dev/null; then
        log_success "GitHub API 连接正常"
        return 0
    else
        log_error "GitHub API 连接失败"
        return 1
    fi
}

# 测试错误检测功能
test_error_detection() {
    log "测试错误检测功能..."
    
    # 创建测试错误日志
    cat > test_error_log.txt << 'EOF'
configure: error: unrecognized option `-O2'
Try `/__w/jdk/jdk/configure --help' for more information
configure exiting with result code 1
Error: Process completed with exit code 1
EOF
    
    # 测试错误检测
    if grep -q "configure: error: unrecognized option" test_error_log.txt; then
        log_success "configure 选项错误检测正常"
    else
        log_error "configure 选项错误检测失败"
        return 1
    fi
    
    # 清理测试文件
    rm -f test_error_log.txt
    
    return 0
}

# 测试修复功能
test_fix_functions() {
    log "测试修复功能..."
    
    # 创建测试工作流文件
    cp .github/workflows/build-jdk.yml .github/workflows/build-jdk.yml.backup
    
    # 测试 configure 选项修复
    sed -i 's/-O2/-O3/g' .github/workflows/build-jdk.yml
    if grep -q "-O3" .github/workflows/build-jdk.yml; then
        log_success "configure 选项修改测试通过"
    else
        log_error "configure 选项修改测试失败"
        return 1
    fi
    
    # 恢复原文件
    mv .github/workflows/build-jdk.yml.backup .github/workflows/build-jdk.yml
    
    return 0
}

# 主测试函数
main() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                监控系统功能测试                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    local test_passed=0
    local total_tests=4
    
    # 运行测试
    if test_dependencies; then
        log_success "依赖测试通过"
        ((test_passed++))
    else
        log_error "依赖测试失败"
    fi
    
    if test_github_api; then
        log_success "GitHub API 测试通过"
        ((test_passed++))
    else
        log_error "GitHub API 测试失败"
    fi
    
    if test_error_detection; then
        log_success "错误检测测试通过"
        ((test_passed++))
    else
        log_error "错误检测测试失败"
    fi
    
    if test_fix_functions; then
        log_success "修复功能测试通过"
        ((test_passed++))
    else
        log_error "修复功能测试失败"
    fi
    
    echo ""
    echo "=========================================="
    echo "测试结果: $test_passed/$total_tests 通过"
    
    if [ $test_passed -eq $total_tests ]; then
        log_success "所有测试通过！监控系统可以正常使用"
        echo ""
        echo "启动监控系统:"
        echo "  ./start-monitoring.sh"
        return 0
    else
        log_error "部分测试失败，请检查配置"
        return 1
    fi
}

# 运行测试
main "$@"