#!/bin/bash
# Buddy Patch - 替换 accountUuid 并在运行期间持续守护
# 用法: ./buddy-patch.sh [目标ID]
# 退出后自动还原

CONFIG="$HOME/.claude.json"

# 解析参数
RENEW=false
TARGET_ID=""
for arg in "$@"; do
  case "$arg" in
    --renew) RENEW=true ;;
    *) [ -z "$TARGET_ID" ] && TARGET_ID="$arg" ;;
  esac
done
TARGET_ID="${TARGET_ID:-d85d758c-c040-4a19-876d-578e72aa7bc3}"

# --renew: 删除 companion 字段，强制重新孵化
if [ "$RENEW" = true ]; then
  if python3 -c "
import json
with open('$CONFIG') as f: d = json.load(f)
if 'companion' in d:
    del d['companion']
    with open('$CONFIG', 'w') as f: json.dump(d, f, indent=2, ensure_ascii=False)
    print('companion 字段已删除，下次 /buddy 将重新孵化')
else:
    print('companion 字段不存在，无需操作')
"; then true; fi
fi

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
