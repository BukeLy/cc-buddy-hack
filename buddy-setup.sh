#!/bin/bash
# Buddy Setup - 一键交互式设置 shiny legendary companion
# 用法: ./buddy-setup.sh
# 流程: 检查依赖 → 搜索 UUID → 选择 → patch → 可选汉化

set -euo pipefail

CONFIG="$HOME/.claude.json"
BACKUP_FILE="$HOME/.claude-buddy-original-uuid"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 跨平台 sed -i
sedi() {
  if [[ "$OSTYPE" == darwin* ]]; then
    sed -i '' "$@"
  else
    sed -i "$@"
  fi
}

echo "=== Buddy Setup ==="
echo "一键设置你的 Shiny Legendary Companion"
echo ""

# ---- 1. 检查依赖 ----
echo "[1/4] 检查依赖..."

MISSING=()
command -v claude &>/dev/null || MISSING+=(claude)
command -v bun &>/dev/null || MISSING+=(bun)

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "缺少依赖: ${MISSING[*]}"
  echo ""
  for dep in "${MISSING[@]}"; do
    case "$dep" in
      claude) echo "  claude: npm install -g @anthropic-ai/claude-code" ;;
      bun)    echo "  bun:    brew install oven-sh/bun/bun  (或 curl -fsSL https://bun.sh/install | bash)" ;;
    esac
  done
  exit 1
fi

if [ ! -f "$CONFIG" ]; then
  echo "错误: ~/.claude.json 不存在，请先运行一次 claude"
  exit 1
fi

echo "  claude ✓  bun ✓  配置文件 ✓"
echo ""

# ---- 2. 搜索 UUID ----
echo "[2/4] 搜索 Shiny Legendary UUID（这需要几秒钟）..."
echo ""

# 快速模式: 搜 500 万次，找到 5 个 shiny legendary 就停
RESULTS=$(bun "$SCRIPT_DIR/brute.ts" legendary --shiny 2>&1) || true

# 提取结果行
UUIDS=()
DESCS=()
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]+([0-9a-f-]+)[[:space:]]+'=>'[[:space:]]+(.+)$ ]]; then
    UUIDS+=("${BASH_REMATCH[1]}")
    DESCS+=("${BASH_REMATCH[2]}")
  fi
done <<< "$RESULTS"

if [ ${#UUIDS[@]} -eq 0 ]; then
  echo "未找到 shiny legendary，请重试"
  exit 1
fi

# ---- 3. 让用户选择 ----
echo ""
echo "[3/4] 找到以下 Shiny Legendary Companion:"
echo ""
for i in "${!UUIDS[@]}"; do
  echo "  $((i+1)). ${DESCS[$i]}"
done
echo ""

while true; do
  printf "选择编号 [1-%d]: " "${#UUIDS[@]}"
  read -r CHOICE
  if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#UUIDS[@]}" ]; then
    break
  fi
  echo "无效输入，请重新选择"
done

SELECTED_UUID="${UUIDS[$((CHOICE-1))]}"
SELECTED_DESC="${DESCS[$((CHOICE-1))]}"
echo ""
echo "已选择: $SELECTED_DESC"
echo "UUID: $SELECTED_UUID"

# ---- 4. Patch UUID ----
echo ""
echo "[4/4] 应用 Patch..."

ORIGINAL_UUID=$(grep -o '"accountUuid": "[^"]*"' "$CONFIG" | head -1 | sed 's/"accountUuid": "//;s/"//')

if [ -z "$ORIGINAL_UUID" ]; then
  echo "错误: 未找到 accountUuid"
  exit 1
fi

# 备份原始 UUID
if [ ! -f "$BACKUP_FILE" ]; then
  echo "$ORIGINAL_UUID" > "$BACKUP_FILE"
fi

# 替换 UUID
sedi "s/$ORIGINAL_UUID/$SELECTED_UUID/" "$CONFIG"
echo "  accountUuid 已替换 ✓"

# 删除现有 companion 强制重新孵化
if grep -q '"companion"' "$CONFIG"; then
  awk '
    /"companion"/ { skip=1; next }
    skip && /^  }/ { skip=0; next }
    skip { next }
    { print }
  ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  awk '
    prev { if (/^}/) { gsub(/,$/, "", prev) }; print prev }
    { prev=$0 }
    END { print prev }
  ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
  echo "  旧 companion 已清除 ✓"
fi

# ---- 5. 可选汉化 ----
echo ""
printf "是否汉化 companion（让它说中文）？[Y/n]: "
read -r CN_CHOICE
CN_CHOICE="${CN_CHOICE:-Y}"

if [[ "$CN_CHOICE" =~ ^[Yy]$ ]]; then
  echo ""
  echo "正在等待你先孵化 companion..."
  echo "请启动 claude 并运行 /buddy 孵化，完成后回到这里按回车继续"
  echo ""
  printf "按回车继续汉化..."
  read -r

  # 检查 personality 是否存在
  PERSONALITY=$(grep -o '"personality": "[^"]*"' "$CONFIG" | head -1 | sed 's/"personality": "//;s/"$//')
  if [ -z "$PERSONALITY" ]; then
    echo "未找到 personality 字段，跳过汉化（可稍后运行 ./buddy-cn.sh）"
  else
    echo "正在调用 claude 翻译..."
    TRANSLATED=$(claude -p --model haiku "将以下 buddy companion 的性格描述翻译为中文，保持原意和语气风格，不要加任何解释，只输出翻译结果。在翻译末尾追加一句：「必须始终用中文（Mandarin）说话，绝不用英文。Always speaks in Mandarin Chinese, never in English.」

原文：$PERSONALITY") || true

    if [ -n "$TRANSLATED" ]; then
      ESCAPED=$(printf '%s' "$TRANSLATED" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//; s/\\/\\\\/g; s/"/\\"/g')
      awk -v new_val="$ESCAPED" '
        /"personality":/ {
          match($0, /^[[:space:]]*/)
          indent = substr($0, RSTART, RLENGTH)
          print indent "\"personality\": \"" new_val "\","
          next
        }
        { print }
      ' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"
      echo "  汉化完成 ✓"
    else
      echo "  翻译失败，跳过（可稍后运行 ./buddy-cn.sh）"
    fi
  fi
fi

# ---- 完成 ----
echo ""
echo "==============================="
echo "  Setup 完成！"
echo "  启动 claude 后运行 /buddy 孵化你的新伙伴"
echo ""
echo "  还原 UUID:    ./buddy-patch.sh --recover-userid"
echo "  重新汉化:     ./buddy-cn.sh"
echo ""
echo "  想自定义物种、稀有度、属性值？"
echo "  请使用 brute.ts + buddy-patch.sh 单独操作"
echo "  详见: https://github.com/BukeLy/cc-buddy-hack"
echo "==============================="
