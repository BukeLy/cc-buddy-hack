#!/bin/bash
# Buddy CN - 汉化 companion 的 personality 描述
# 调用 claude CLI 将英文 personality 翻译为中文，并强制中文说话
# 用法: ./buddy-cn.sh

set -euo pipefail

CONFIG="$HOME/.claude.json"

# 检查依赖
if ! command -v claude &>/dev/null; then
  echo "错误: 未找到 claude 命令"
  echo "安装: npm install -g @anthropic-ai/claude-code"
  exit 1
fi

# 检查配置文件
if [ ! -f "$CONFIG" ]; then
  echo "错误: 配置文件不存在: $CONFIG"
  exit 1
fi

# 提取当前 personality
PERSONALITY=$(grep -o '"personality": "[^"]*"' "$CONFIG" | head -1 | sed 's/"personality": "//;s/"$//')

if [ -z "$PERSONALITY" ]; then
  echo "错误: 未找到 companion personality 字段"
  echo "请先使用 /buddy 孵化一个 companion"
  exit 1
fi

echo "=== Buddy CN 汉化 ==="
echo "当前 personality:"
echo "  $PERSONALITY"
echo ""
echo "正在调用 claude 翻译..."

# 调用 claude -p 翻译 personality
TRANSLATED=$(claude -p --model haiku "将以下 buddy companion 的性格描述翻译为中文，保持原意和语气风格，不要加任何解释，只输出翻译结果。在翻译末尾追加一句：「必须始终用中文（Mandarin）说话，绝不用英文。Always speaks in Mandarin Chinese, never in English.」

原文：$PERSONALITY")

if [ -z "$TRANSLATED" ]; then
  echo "错误: 翻译结果为空"
  exit 1
fi

echo ""
echo "翻译结果:"
echo "  $TRANSLATED"
echo ""

# 将翻译结果合并为单行并转义 JSON 特殊字符
ESCAPED=$(printf '%s' "$TRANSLATED" | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//; s/\\/\\\\/g; s/"/\\"/g')

# 替换 personality 字段
awk -v new_val="$ESCAPED" '
  /"personality":/ {
    match($0, /^[[:space:]]*/)
    indent = substr($0, RSTART, RLENGTH)
    print indent "\"personality\": \"" new_val "\","
    next
  }
  { print }
' "$CONFIG" > "$CONFIG.tmp" && mv "$CONFIG.tmp" "$CONFIG"

echo "汉化完成！立即生效。"
