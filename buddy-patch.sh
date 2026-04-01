#!/bin/bash
# Buddy Patch - 替换 accountUuid 并在运行期间持续守护
# 用法: ./buddy-patch.sh [目标ID]
# 退出后自动还原

CONFIG="$HOME/.claude.json"
TARGET_ID="${1:-d85d758c-c040-4a19-876d-578e72aa7bc3}"

# 读取原始 UUID
ORIGINAL_UUID=$(grep -o '"accountUuid": "[^"]*"' "$CONFIG" | head -1 | sed 's/"accountUuid": "//;s/"//')

if [ -z "$ORIGINAL_UUID" ]; then
  echo "未找到 accountUuid，直接启动 claude"
  exec claude "$@"
fi

echo "=== Buddy Patch ==="
echo "原始: $ORIGINAL_UUID"
echo "目标: $TARGET_ID"

# 替换函数
patch() {
  if grep -q "$ORIGINAL_UUID" "$CONFIG" 2>/dev/null; then
    sed -i '' "s/$ORIGINAL_UUID/$TARGET_ID/" "$CONFIG"
  fi
}

# 还原函数
restore() {
  sed -i '' "s/$TARGET_ID/$ORIGINAL_UUID/" "$CONFIG" 2>/dev/null
}

# 首次替换
patch

# 后台守护：文件被改回时自动 re-patch（防止 token 刷新写回原值）
(
  while true; do
    sleep 2
    if grep -q "$ORIGINAL_UUID" "$CONFIG" 2>/dev/null; then
      sed -i '' "s/$ORIGINAL_UUID/$TARGET_ID/" "$CONFIG"
    fi
  done
) &
WATCHER_PID=$!

# 退出时还原 + 杀守护进程
cleanup() {
  kill $WATCHER_PID 2>/dev/null
  wait $WATCHER_PID 2>/dev/null
  restore
  echo ""
  echo "accountUuid 已还原"
}
trap cleanup EXIT INT TERM

# 启动 claude（传递所有参数）
claude "$@"
