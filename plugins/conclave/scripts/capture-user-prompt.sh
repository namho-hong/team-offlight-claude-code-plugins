#!/bin/bash
# Claude UserPromptSubmit Hook
# 사용자 프롬프트 원문을 Conclave messages로 저장

if [[ -z "${CONCLAVE_TERMINAL:-}" ]]; then
  exit 0
fi

MCP_URL="http://127.0.0.1:${CONCLAVE_MCP_PORT:-57537}/mcp"
MCP_TOKEN="${CONCLAVE_MCP_TOKEN:-}"

if [[ -z "$MCP_TOKEN" ]]; then
  exit 0
fi

HOOK_INPUT=$(cat)
PROMPT=$(echo "$HOOK_INPUT" | jq -r '.prompt // empty')
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')
SIGNAL_SESSION_ID="${CONCLAVE_AGENT_SESSION_ID:-$SESSION_ID}"

if [[ -z "$SIGNAL_SESSION_ID" ]]; then
  exit 0
fi

if [[ -z "$PROMPT" ]]; then
  exit 0
fi

REQUEST_JSON=$(jq -n \
  --arg sid "$SIGNAL_SESSION_ID" \
  --arg prompt "$PROMPT" \
  '{
    "jsonrpc": "2.0",
    "id": "terminal-user-prompt",
    "method": "tools/call",
    "params": {
      "name": "ingest_terminal_message",
      "arguments": {
        "agentType": "claude",
        "externalSessionId": $sid,
        "role": "user",
        "content": $prompt,
        "source": "claude-user-prompt-hook"
      }
    }
  }')

curl -s -X POST "$MCP_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $MCP_TOKEN" \
  -d "$REQUEST_JSON" > /dev/null 2>&1

exit 0
