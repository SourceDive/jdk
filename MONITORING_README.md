# GitHub Actions 自动监控和修复系统

## 🎯 功能概述

这是一个智能的 GitHub Actions 监控系统，能够：
- 🔍 **持续监控** 工作流运行状态
- 🔧 **自动检测** 常见错误类型
- 🛠️ **自动修复** 配置和代码问题
- 🔄 **自动重试** 修复后的工作流
- 📊 **实时报告** 监控状态和修复结果

## 🚀 快速开始

### 1. 启动监控系统

```bash
# 给脚本执行权限
chmod +x start-monitoring.sh

# 启动监控系统
./start-monitoring.sh
```

### 2. 选择监控模式

系统提供三种监控模式：

#### 模式1: 持续监控模式 (推荐)
- 每30秒检查一次工作流状态
- 自动检测和修复常见错误
- 适合长期运行

#### 模式2: 完整监控模式
- 详细的错误分析和日志记录
- 更全面的修复策略
- 适合调试和问题排查

#### 模式3: 仅监控模式
- 只监控不修复
- 适合观察和手动干预

## 📁 文件说明

### 核心脚本
- `start-monitoring.sh` - 主启动脚本
- `continuous-monitor.sh` - 持续监控脚本
- `monitor-and-fix.sh` - 完整监控和修复脚本

### GitHub Actions 工作流
- `.github/workflows/auto-monitor-fix.yml` - 自动监控工作流
- `.github/workflows/build-jdk.yml` - 主构建工作流

## 🔧 自动修复功能

### 支持的错误类型

1. **Configure 选项错误**
   - 检测: `configure: error: unrecognized option`
   - 修复: 修正 configure 参数格式

2. **权限错误**
   - 检测: `Permission denied`
   - 修复: 设置正确的文件权限

3. **依赖缺失错误**
   - 检测: `autoconf not found`
   - 修复: 安装缺失的依赖包

4. **磁盘空间错误**
   - 检测: `No space left on device`
   - 修复: 清理临时文件和缓存

5. **超时错误**
   - 检测: `timeout`
   - 修复: 增加超时时间，减少并行度

6. **Make 错误**
   - 检测: `make: ***`
   - 修复: 清理构建目录，重新配置

7. **Javac 错误**
   - 检测: `javac: error`
   - 修复: 设置正确的 Java 环境

8. **GCC 错误**
   - 检测: `gcc: error`
   - 修复: 安装完整的编译工具链

### 修复流程

```
检测错误 → 分析错误类型 → 应用修复策略 → 提交修复 → 重新触发工作流
```

## 📊 监控界面

### 实时状态显示
```
[14:30:15] 检查工作流状态 (第 1 次)
[14:30:15] 状态: completed, 结论: failure
[14:30:15] ❌ 工作流失败，开始修复...
[14:30:15] 检测到错误类型: configure_option_error
[14:30:16] 修复 configure 选项...
[14:30:16] ✅ configure 选项已修复
[14:30:17] 已重新触发工作流
[14:30:17] 工作流正在运行，等待 30 秒...
```

### 错误分析报告
```
=== 错误分析报告 ===
错误类型: configure_option_error
错误摘要: configure: error: unrecognized option `-O2'
修复策略: 修正 configure 参数格式
修复状态: 成功
重试状态: 已重新触发
```

## ⚙️ 配置选项

### 环境变量
```bash
export GITHUB_TOKEN="your_token_here"  # GitHub 访问令牌
export REPO_OWNER="SourceDive"         # 仓库所有者
export REPO_NAME="jdk"                 # 仓库名称
export CHECK_INTERVAL=30               # 检查间隔（秒）
export MAX_ATTEMPTS=100                # 最大尝试次数
```

### 监控参数
- **检查间隔**: 30秒 (可调整)
- **最大尝试次数**: 100次
- **超时时间**: 2小时
- **重试间隔**: 60秒

## 🔍 故障排查

### 常见问题

1. **GitHub CLI 未安装**
   ```bash
   # Linux
   curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
   
   # macOS
   brew install gh
   ```

2. **认证失败**
   ```bash
   gh auth login
   ```

3. **权限不足**
   - 确保 GitHub Token 有足够的权限
   - 检查仓库的 Actions 权限设置

4. **监控脚本无法运行**
   ```bash
   chmod +x *.sh
   ```

### 日志文件
- 错误日志: `/tmp/error_log.txt`
- 工作流日志: `/tmp/workflow_logs.txt`
- 监控日志: 控制台输出

## 📈 性能优化

### 监控效率
- 使用 GitHub API 的增量查询
- 智能错误检测算法
- 并行处理多个工作流

### 修复效率
- 基于错误类型的快速修复
- 避免不必要的重试
- 智能的修复策略选择

## 🛡️ 安全考虑

- 使用 GitHub Token 进行认证
- 所有修复操作都有日志记录
- 自动提交的修复都有明确的标识
- 支持回滚和手动干预

## 📞 支持

如果遇到问题，请检查：
1. GitHub CLI 是否正确安装和认证
2. 仓库权限是否足够
3. 网络连接是否正常
4. 错误日志中的具体信息

## 🔄 更新和维护

系统会自动：
- 检测新的错误类型
- 更新修复策略
- 优化监控效率
- 保持与 GitHub API 的兼容性

---

**注意**: 这个系统设计为在您的本地机器或服务器上运行，持续监控 GitHub Actions 的工作流状态。确保有稳定的网络连接和足够的权限。