#!/bin/bash
# Agent 응답 완료 알림 - Stop Hook
# Claude가 응답을 끝낼 때마다 실행됨
# Conclave 앱이 포커스 상태가 아니면 OS 알림 표시

# Conclave 터미널에서만 동작
if [[ -z "${CONCLAVE_TERMINAL:-}" ]]; then
  exit 0
fi

# MCP 연결 정보 확인
MCP_URL="http://127.0.0.1:${CONCLAVE_MCP_PORT:-57537}/mcp"
MCP_TOKEN="${CONCLAVE_MCP_TOKEN:-}"

if [[ -z "$MCP_TOKEN" ]]; then
  exit 0
fi

# stdin 소비 (Stop 훅은 stdin으로 JSON 받음)
HOOK_INPUT=$(cat)
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')
SIGNAL_SESSION_ID="${CONCLAVE_AGENT_SESSION_ID:-$SESSION_ID}"
if [[ -z "$SIGNAL_SESSION_ID" ]]; then
  SIGNAL_SESSION_ID="unknown-claude-session"
fi
ORIGIN_NODE_ID="${CONCLAVE_NODE_ID:-$CONCLAVE_AGENT_SESSION_ID}"
ORIGIN_NODE_TYPE="${CONCLAVE_NODE_TYPE:-agent_session}"

# ULP 루프 활성 상태면 알림 스킵 (루프 중간에 알림 불필요)
if [[ -n "$SESSION_ID" ]]; then
  ULP_STATE_FILE="$HOME/.claude/ulp-state/$SESSION_ID.json"
  if [[ -f "$ULP_STATE_FILE" ]]; then
    exit 0
  fi
fi

# transcript에서 마지막 assistant 메시지 텍스트 추출
# Stop 훅은 Claude Code가 transcript 쓰기 전에 실행될 수 있어서 딜레이 필요
sleep 0.5

BODY="Response complete"
LAST_MSG=""
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  LAST_MSG=$(grep '"type":"assistant"' "$TRANSCRIPT_PATH" | tail -1 | jq -r '.message.content[-1].text // empty' 2>/dev/null)
  if [[ -n "$LAST_MSG" ]]; then
    # 200자로 truncate
    BODY=$(echo "$LAST_MSG" | head -c 200)
  fi
fi

# 공통 MCP 호출 함수
call_mcp_tool() {
  local request_json="$1"
  curl -s -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $MCP_TOKEN" \
    -H "X-Conclave-Node-Id: ${ORIGIN_NODE_ID:-}" \
    -H "X-Conclave-Node-Type: ${ORIGIN_NODE_TYPE:-}" \
    -d "$request_json" > /dev/null 2>&1
}

# assistant 메시지 저장 (본문이 있을 때만)
if [[ -n "$LAST_MSG" ]]; then
  INGEST_MSG_REQ=$(jq -n \
    --arg sid "$SIGNAL_SESSION_ID" \
    --arg content "$LAST_MSG" \
    '{
      "jsonrpc": "2.0",
      "id": "terminal-assistant-stop",
      "method": "tools/call",
      "params": {
        "name": "ingest_terminal_message",
        "arguments": {
          "agentType": "claude",
          "externalSessionId": $sid,
          "role": "assistant",
          "content": $content,
          "source": "claude-stop-hook"
        }
      }
    }')
  call_mcp_tool "$INGEST_MSG_REQ"
fi

# Turn signal 반영 + OS notification (single MCP call)
TURN_SIGNAL_REQ=$(jq -n \
  --arg sid "$SIGNAL_SESSION_ID" \
  --arg body "$BODY" \
  '{
    "jsonrpc": "2.0",
    "id": "turn-signal-stop",
    "method": "tools/call",
    "params": {
      "name": "ingest_turn_signal",
      "arguments": {
        "agentType": "claude",
        "externalSessionId": $sid,
        "state": "human",
        "source": "claude-stop-hook",
        "notification": {
          "title": "Agent",
          "body": $body
        }
      }
    }
  }')
call_mcp_tool "$TURN_SIGNAL_REQ"

exit 0
