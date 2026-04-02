#!/bin/bash
# Buddy Patch - 替换 accountUuid 并在运行期间持续守护
# 用法: ./buddy-patch.sh [目标ID] [选项]
# 退出后保持替换（永久生效），使用 --recover-userid 手动还原

set -eo pipefail

CONFIG="$HOME/.claude.json"
BACKUP_FILE="$HOME/.claude-buddy-original-uuid"

# 跨平台 sed -i
sedi() {
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

# 用法说明
usage() {
  cat <<'EOF'
用法: ./buddy-patch.sh [目标UUID] [选项] [-- claude参数...]

选项:
  --renew            删除 companion 字段，强制重新孵化
  --recover-userid   还原为原始 accountUuid 并退出
  --help             显示此帮助信息

示例:
  ./buddy-patch.sh                                    # 使用默认目标 UUID
  ./buddy-patch.sh abc-123-def                        # 指定目标 UUID
  ./buddy-patch.sh abc-123-def --renew                # 指定 UUID 并重新孵化
  ./buddy-patch.sh --recover-userid                   # 还原原始 UUID
  ./buddy-patch.sh abc-123-def -- --resume            # 传递参数给 claude
EOF
  exit 0
}

# 检查依赖
check_deps() {
  if ! command -v claude &>/dev/null; then
    echo "错误: 未找到 claude 命令"
    echo "安装: npm install -g @anthropic-ai/claude-code"
    exit 1
  fi
}

# UUID 格式校验 (8-4-4-4-12)
validate_uuid() {
  local uuid="$1"
  if [[ ! "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
    echo "错误: 无效的 UUID 格式: $uuid"
    echo "期望格式: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
    exit 1
  fi
}

# 解析参数
RENEW=false
RECOVER=false
TARGET_ID=""
CLAUDE_ARGS=()
PARSING_CLAUDE_ARGS=false
for arg in "$@"; do
  if [ "$PARSING_CLAUDE_ARGS" = true ]; then
    CLAUDE_ARGS+=("$arg")
    continue
  fi
  case "$arg" in
    --help|-h) usage ;;
    --renew) RENEW=true ;;
    --recover-userid) RECOVER=true ;;
    --)  PARSING_CLAUDE_ARGS=true ;;
    -*)  echo "错误: 未知选项: $arg"; echo "使用 --help 查看帮助"; exit 1 ;;
    *)
      if [ -z "$TARGET_ID" ]; then
        TARGET_ID="$arg"
      else
        echo "错误: 多余的参数: $arg"; echo "使用 --help 查看帮助"; exit 1
      fi
      ;;
  esac
done
TARGET_ID="${TARGET_ID:-d85d758c-c040-4a19-876d-578e72aa7bc3}"

# 校验 UUID 格式
validate_uuid "$TARGET_ID"

# 检查依赖
check_deps

# 检查配置文件
if [ ! -f "$CONFIG" ]; then
  echo "错误: 配置文件不存在: $CONFIG"
  echo "请先运行一次 claude 以生成配置文件"
  exit 1
fi

# --recover-userid: 从备份还原原始 UUID 并退出
if [ "$RECOVER" = true ]; then
  if [ ! -f "$BACKUP_FILE" ]; then
    echo "错误: 未找到备份文件 $BACKUP_FILE，无法还原"
    echo "可能从未使用过 buddy-patch，或已经还原过了"
    exit 1
  fi
  ORIGINAL_UUID=$(cat "$BACKUP_FILE")
  validate_uuid "$ORIGINAL_UUID"
  CURRENT_UUID=$(grep -o '"accountUuid": "[^"]*"' "$CONFIG" | head -1 | sed 's/"accountUuid": "//;s/"//')
  if [ "$CURRENT_UUID" = "$ORIGINAL_UUID" ]; then
    echo "accountUuid 已经是原始值，无需还原"
  else
    sedi "s/$CURRENT_UUID/$ORIGINAL_UUID/" "$CONFIG"
    echo "accountUuid 已还原为: $ORIGINAL_UUID"
  fi
  rm -f "$BACKUP_FILE"
  exit 0
fi

# --renew: 删除 companion 字段，强制重新孵化
if [ "$RENEW" = true ]; then
  if grep -q '"companion"' "$CONFIG"; then
    # 用 awk 删除 "companion": { ... } 块并处理逗号
    awk '
      /"companion"/ { skip=1; next }
      skip && /^  }/ { skip=0; next }
      skip { next }
      { print }
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    # 修复尾部逗号: },\n} -> }\n}
    awk '
      prev { if (/^}/) { gsub(/,$/, "", prev) }; print prev }
      { prev=$0 }
      END { print prev }
    ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
    echo "companion 字段已删除，下次 /buddy 将重新孵化"
  else
    echo "companion 字段不存在，无需操作"
  fi
fi

# 读取原始 UUID
ORIGINAL_UUID=$(grep -o '"accountUuid": "[^"]*"' "$CONFIG" | head -1 | sed 's/"accountUuid": "//;s/"//')

if [ -z "$ORIGINAL_UUID" ]; then
  echo "未找到 accountUuid，直接启动 claude"
  exec claude "${CLAUDE_ARGS[@]}"
fi

# 保存原始 UUID 到备份文件（仅在尚未备份时保存，避免覆盖真正的原始值）
if [ ! -f "$BACKUP_FILE" ]; then
  echo "$ORIGINAL_UUID" > "$BACKUP_FILE"
fi

echo "=== Buddy Patch ==="
echo "原始: $ORIGINAL_UUID"
echo "目标: $TARGET_ID"
echo "退出后将保持替换（使用 --recover-userid 手动还原）"

# 替换函数
patch() {
  if grep -q "$ORIGINAL_UUID" "$CONFIG" 2>/dev/null; then
    sedi "s/$ORIGINAL_UUID/$TARGET_ID/" "$CONFIG"
  fi
}

# 首次替换
patch

# 后台守护：文件被改回时自动 re-patch（防止 token 刷新写回原值）
(
  while true; do
    sleep 2
    if grep -q "$ORIGINAL_UUID" "$CONFIG" 2>/dev/null; then
      sedi "s/$ORIGINAL_UUID/$TARGET_ID/" "$CONFIG"
    fi
  done
) &
WATCHER_PID=$!

# 退出时只杀守护进程，不还原 UUID
cleanup() {
  kill $WATCHER_PID 2>/dev/null
  wait $WATCHER_PID 2>/dev/null
  echo ""
  echo "accountUuid 保持为目标值（使用 ./buddy-patch.sh --recover-userid 还原）"
}
trap cleanup EXIT INT TERM

# 启动 claude（传递所有参数）
claude "${CLAUDE_ARGS[@]}"
