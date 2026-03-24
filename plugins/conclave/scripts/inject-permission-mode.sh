#!/bin/bash
# PreToolUse Hook: Claude Code의 permission_mode를 edit_note tool_input에 주입
# Claude Code가 MCP edit_note를 호출할 때, 현재 permission_mode를 tool_input에 포함시켜
# MCP 서버가 directApply 여부를 결정할 수 있게 함.

# Conclave 터미널에서만 동작
if [[ -z "${CONCLAVE_TERMINAL:-}" ]]; then
  exit 0
fi

HOOK_INPUT=$(cat)
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty')

# edit_note MCP 도구만 대상
if [[ "$TOOL_NAME" != "mcp__conclave-dev__edit_note" ]]; then
  exit 0
fi

PERMISSION_MODE=$(echo "$HOOK_INPUT" | jq -r '.permission_mode // "default"')
TOOL_INPUT=$(echo "$HOOK_INPUT" | jq -r '.tool_input')

# tool_input에 permissionMode 주입
UPDATED_INPUT=$(echo "$TOOL_INPUT" | jq --arg mode "$PERMISSION_MODE" '. + {permissionMode: $mode}')

# hookSpecificOutput 형식으로 반환
jq -n --argjson input "$UPDATED_INPUT" '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "updatedInput": $input
  }
}'
