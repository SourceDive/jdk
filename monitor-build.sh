#!/bin/bash

RUN_ID=$1
if [ -z "$RUN_ID" ]; then
    echo "Usage: $0 <run-id>"
    exit 1
fi

echo "监控 GitHub Actions 运行 ID: $RUN_ID"
echo "========================================="

while true; do
    STATUS=$(gh run view $RUN_ID --json status -q .status 2>/dev/null)
    
    if [ -z "$STATUS" ]; then
        echo "无法获取运行状态"
        sleep 30
        continue
    fi
    
    echo -n "$(date '+%H:%M:%S') - 状态: $STATUS"
    
    if [ "$STATUS" = "in_progress" ]; then
        # 获取当前步骤
        CURRENT_STEP=$(gh run view $RUN_ID 2>/dev/null | grep -E "^\s*\*" | tail -1 | sed 's/^\s*\*//' | xargs)
        echo " - 当前步骤: $CURRENT_STEP"
    else
        echo ""
        break
    fi
    
    sleep 60
done

echo ""
echo "运行结束，最终状态: $STATUS"
echo ""

# 显示完整结果
gh run view $RUN_ID

# 如果成功，检查缓存信息
if [ "$STATUS" = "completed" ]; then
    echo ""
    echo "=== 缓存信息 ==="
    gh run view $RUN_ID --log 2>/dev/null | grep -A 10 "显示缓存状态" | grep -E "缓存|cache|哈希" | head -20
fi