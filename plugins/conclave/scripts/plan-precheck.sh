#!/bin/bash
# plan-precheck.sh
# PreToolUse Hook: Write + ~/.claude/plans/*.md 감지 시
# 부모 노드 하위 기존 노트를 수집하여 additionalContext로 AI에게 전달
# Write는 절대 차단하지 않음 (항상 exit 0)

set -euo pipefail

# ========== stdin에서 JSON 읽기 ==========
INPUT_JSON=$(cat)

# ========== 기본 필터링 ==========
TOOL_NAME=$(echo "$INPUT_JSON" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$INPUT_JSON" | jq -r '.tool_input.file_path // .tool_input.filePath // ""')
PLANS_DIR="$HOME/.claude/plans"

# Write가 아니면 통과
if [[ "$TOOL_NAME" != "Write" ]]; then
  exit 0
fi

# ~/.claude/plans/*.md가 아니면 통과
if [[ "$FILE_PATH" != "$PLANS_DIR"/*.md ]]; then
  exit 0
fi

# 파일이 이미 존재하면 통과 (수정이므로 PostToolUse에서 처리)
if [[ -f "$FILE_PATH" ]]; then
  exit 0
fi

# Conclave 터미널이 아니면 통과
if [[ -z "${CONCLAVE_TERMINAL:-}" ]]; then
  exit 0
fi

# NODE_ID 없으면 통과 (PostToolUse에서 루트 생성)
if [[ -z "${CONCLAVE_NODE_ID:-}" ]]; then
  exit 0
fi

# agent_session이 아니면 통과
if [[ "${CONCLAVE_NODE_TYPE:-}" != "agent_session" ]]; then
  exit 0
fi

# MCP 토큰 없으면 통과
MCP_URL="http://127.0.0.1:${CONCLAVE_MCP_PORT:-57537}/mcp"
MCP_TOKEN="${CONCLAVE_MCP_TOKEN:-}"
if [[ -z "$MCP_TOKEN" ]]; then
  exit 0
fi

# ========== MCP 호출 헬퍼 ==========
LOG_FILE="/tmp/plan-precheck.log"
FILENAME=$(basename "$FILE_PATH")

call_mcp() {
  local id="$1"
  local tool_name="$2"
  local arguments="$3"

  curl -s -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $MCP_TOKEN" \
    -d "{
      \"jsonrpc\": \"2.0\",
      \"id\": \"$id\",
      \"method\": \"tools/call\",
      \"params\": {
        \"name\": \"$tool_name\",
        \"arguments\": $arguments
      }
    }" 2>/dev/null || echo '{"error": "curl failed"}'
}

extract_notes() {
  local response="$1"
  echo "$response" | jq -r '.result.content[0].text // ""' | grep '\[note\]' || true
}

# ========== 부모 노드 하위 전체 노트 수집 ==========
echo "$(date): [PRECHECK] $FILENAME under node $CONCLAVE_NODE_ID" >> "$LOG_FILE"

ALL_NOTES=""

# get_node로 부모 ID + 부모 타입 획득
NODE_RESPONSE=$(call_mcp "get-node" "get_node" \
  "{\"path\": \"/agent_sessions/$CONCLAVE_NODE_ID\", \"format\": \"json\"}")
NODE_JSON=$(echo "$NODE_RESPONSE" | jq -r '.result.content[0].text // ""')
PARENT_ID=$(echo "$NODE_JSON" | jq -r '.contentJson.parentId // ""' 2>/dev/null || echo "")
PARENT_TYPE=$(echo "$NODE_JSON" | jq -r '.contentJson.parentType // ""' 2>/dev/null || echo "")

echo "  Parent ID: ${PARENT_ID:-none}, Parent Type: ${PARENT_TYPE:-none}" >> "$LOG_FILE"

if [[ -n "$PARENT_ID" && -n "$PARENT_TYPE" ]]; then
  PARENT_PATH_TYPE="${PARENT_TYPE}s"
  PARENT_RESPONSE=$(call_mcp "list-parent-children" "list_tree" \
    "{\"path\": \"/${PARENT_PATH_TYPE}/${PARENT_ID}/children\", \"limit\": 50}")
  PARENT_CHILDREN=""
  if echo "$PARENT_RESPONSE" | jq -e '.result.content[0].text' > /dev/null 2>&1; then
    PARENT_CHILDREN=$(echo "$PARENT_RESPONSE" | jq -r '.result.content[0].text // ""')
  fi

  if [[ -n "$PARENT_CHILDREN" ]]; then
    # 1) 부모 직접 자식 중 노트 수집
    DIRECT_NOTES=$(echo "$PARENT_CHILDREN" | grep '\[note\]' || true)
    if [[ -n "$DIRECT_NOTES" ]]; then
      ALL_NOTES="$DIRECT_NOTES"
    fi

    # 2) 부모 직접 자식 중 agent_session들의 하위 노트 수집
    SESSION_IDS=$(echo "$PARENT_CHILDREN" | grep '\[agent_session\]' | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' || true)
    for SID in $SESSION_IDS; do
      SESSION_CHILDREN=$(call_mcp "list-session-$SID" "list_tree" \
        "{\"path\": \"/agent_sessions/$SID/children\", \"limit\": 50}")
      SESSION_NOTES=$(extract_notes "$SESSION_CHILDREN")
      if [[ -n "$SESSION_NOTES" ]]; then
        if [[ -n "$ALL_NOTES" ]]; then
          ALL_NOTES=$(printf '%s\n%s' "$ALL_NOTES" "$SESSION_NOTES")
        else
          ALL_NOTES="$SESSION_NOTES"
        fi
      fi
    done
  fi
else
  # 부모 없음 → 현재 세션 하위만 조회
  CHILDREN_RESPONSE=$(call_mcp "list-children" "list_tree" \
    "{\"path\": \"/agent_sessions/$CONCLAVE_NODE_ID/children\", \"limit\": 50}")
  ALL_NOTES=$(extract_notes "$CHILDREN_RESPONSE")
fi

NOTE_COUNT=$(echo "$ALL_NOTES" | grep -c '\[note\]' || echo 0)
echo "  Total notes collected: $NOTE_COUNT" >> "$LOG_FILE"

# ========== 결과 처리 ==========
if [[ -z "$ALL_NOTES" || "$NOTE_COUNT" -eq 0 ]]; then
  # 노트 없음 → 아무것도 안 함 (PostToolUse가 자동 생성)
  echo "  No existing notes, passing through" >> "$LOG_FILE"
  exit 0
fi

# 노트 있음 → additionalContext로 AI에게 전달 (Write는 차단하지 않음)
echo "  Found $NOTE_COUNT notes, injecting additionalContext" >> "$LOG_FILE"

NOTE_LIST=""
while IFS= read -r line; do
  if [[ -n "$line" ]]; then
    NOTE_LIST="${NOTE_LIST}\\n- ${line}"
  fi
done <<< "$ALL_NOTES"

CONTEXT_MSG="[Plan Sync] Existing notes found under this context:${NOTE_LIST}\\n\\nAfter the Write completes, check if your plan covers the same topic as any note above. If so, use edit_note to update it and set local_plan_path to link the plan file. If this is a genuinely new topic, the PostToolUse hook will create a new note automatically."

# additionalContext JSON 출력 (Write 허용 + 컨텍스트 주입)
cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"$CONTEXT_MSG"}}
EOF
exit 0
