#!/bin/bash
# plan-sync-to-conclave.sh
# PostToolUse Hook: ~/.claude/plans/*.md 파일을 Conclave Note와 동기화
# Write/Edit 도구 사용 후 트리거됨
#
# 매칭 우선순위:
# 1순위: find_notes(localPlanPath) → 기존 노트 업데이트 (noteId 기반)
# 2순위: 부모 노드 하위 노트 있지만 localPlanPath 불일치 → additionalContext로 AI에게 위임
# 3순위: 부모 노드 하위 노트 없음 → create_note 자동 생성

set -euo pipefail

# Conclave 터미널이 아니면 통과
if [[ -z "${CONCLAVE_TERMINAL:-}" ]]; then
  exit 0
fi

# ========== 설정 ==========
MCP_URL="http://127.0.0.1:${CONCLAVE_MCP_PORT:-57537}/mcp"
MCP_TOKEN="${CONCLAVE_MCP_TOKEN:-}"
LOG_FILE="/tmp/plan-sync.log"
PLANS_DIR="$HOME/.claude/plans"

# ========== stdin에서 JSON 읽기 ==========
INPUT_JSON=$(cat)

# ========== 파일 경로 확인 ==========
TOOL_NAME=$(echo "$INPUT_JSON" | jq -r '.tool_name // ""')
FILE_PATH=$(echo "$INPUT_JSON" | jq -r '.tool_input.file_path // .tool_input.filePath // ""')

# Write 또는 Edit 도구가 아니면 종료
if [[ "$TOOL_NAME" != "Write" && "$TOOL_NAME" != "Edit" ]]; then
  exit 0
fi

# ~/.claude/plans/ 경로가 아니면 종료
if [[ "$FILE_PATH" != "$PLANS_DIR"/* ]]; then
  exit 0
fi

# .md 파일이 아니면 종료
if [[ "$FILE_PATH" != *.md ]]; then
  exit 0
fi

# MCP 토큰 없으면 종료
if [[ -z "$MCP_TOKEN" ]]; then
  echo "$(date): [SKIP] No MCP token" >> "$LOG_FILE"
  exit 0
fi

# ========== 파일명 + 내용 추출 ==========
FILENAME=$(basename "$FILE_PATH")
echo "$(date): [SYNC] $FILENAME (tool: $TOOL_NAME) NODE_ID=${CONCLAVE_NODE_ID:-<empty>} NODE_TYPE=${CONCLAVE_NODE_TYPE:-<empty>}" >> "$LOG_FILE"

if [[ ! -f "$FILE_PATH" ]]; then
  echo "  File not found: $FILE_PATH" >> "$LOG_FILE"
  exit 0
fi

CONTENT=$(cat "$FILE_PATH")

# 제목 추출 (첫 줄 # 헤더)
TITLE=$(echo "$CONTENT" | head -1 | sed 's/^# *//')
if [[ -z "$TITLE" ]]; then
  TITLE="${FILENAME%.md}"
fi

echo "  Title: $TITLE" >> "$LOG_FILE"

# ========== MCP 호출 헬퍼 ==========
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

call_mcp_with_context() {
  local id="$1"
  local tool_name="$2"
  local arguments="$3"

  curl -s -X POST "$MCP_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $MCP_TOKEN" \
    -H "X-Conclave-Node-Id: ${CONCLAVE_NODE_ID:-}" \
    -H "X-Conclave-Node-Type: ${CONCLAVE_NODE_TYPE:-}" \
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

# NODE_TYPE 동적 해석 (NODE_ID는 있지만 NODE_TYPE이 없을 때)
resolve_node_type() {
   local node_id="$1"
   
   # agent_session 시도
   local response
   response=$(call_mcp "get-node-$node_id" "get_node" \
     "{\"path\": \"/agent_sessions/$node_id\", \"format\": \"json\"}")
   
   if echo "$response" | jq -e '.result.content[0].text' > /dev/null 2>&1; then
     local node_json
     node_json=$(echo "$response" | jq -r '.result.content[0].text // ""')
     if echo "$node_json" | jq -e '.contentJson.id' > /dev/null 2>&1; then
       echo "agent_session"
       return 0
     fi
   fi
   
   # task 시도
   response=$(call_mcp "get-node-$node_id" "get_node" \
     "{\"path\": \"/tasks/$node_id\", \"format\": \"json\"}")
   
   if echo "$response" | jq -e '.result.content[0].text' > /dev/null 2>&1; then
     local node_json
     node_json=$(echo "$response" | jq -r '.result.content[0].text // ""')
     if echo "$node_json" | jq -e '.contentJson.id' > /dev/null 2>&1; then
       echo "task"
       return 0
     fi
   fi
   
   # goal 시도
   response=$(call_mcp "get-node-$node_id" "get_node" \
     "{\"path\": \"/goals/$node_id\", \"format\": \"json\"}")
   
   if echo "$response" | jq -e '.result.content[0].text' > /dev/null 2>&1; then
     local node_json
     node_json=$(echo "$response" | jq -r '.result.content[0].text // ""')
     if echo "$node_json" | jq -e '.contentJson.id' > /dev/null 2>&1; then
       echo "goal"
       return 0
     fi
   fi
   
   # 모두 실패
   echo ""
   return 1
}

# edit_note로 노트 내용 업데이트 (read → edit)
# note_id가 있으면 UUID로 직접 조회, 없으면 제목으로 조회
update_note_content() {
    local note_title="$1"
    local new_content="$2"
    local note_id="${3:-}"

    # note_id가 있으면 UUID 사용, 없으면 제목 사용
    local note_identifier
    if [[ -n "$note_id" ]]; then
      note_identifier="$note_id"
    else
      note_identifier="$note_title"
    fi

    # read_note로 현재 내용 조회
    local read_response
    read_response=$(call_mcp "read-$FILENAME" "read_note" \
      "{\"noteTitle\": $(printf '%s' "$note_identifier" | jq -Rs .)}")

    local full_text
    full_text=$(echo "$read_response" | jq -r '.result.content[0].text // ""')
    # "# 제목\n본문...\n---\n## Connected Nodes" 구조에서 본문만 추출
    # 본문 내 ---도 있을 수 있으므로, ## Connected Nodes 직전의 ---만 구분자로 인식
    local old_content
    old_content=$(echo "$full_text" | awk '
      NR == 1 { next }
      /^---$/ { pending = $0; next }
      /^## Connected Nodes/ { exit }
      {
        if (pending != "") { print pending; pending = "" }
        print
      }
    ')

    if [[ -z "$old_content" ]]; then
      echo "  Failed to get current content for '$note_identifier'" >> "$LOG_FILE"
      return 1
    fi

    # 파일 내용에서 첫 줄(# 제목) 제외
    local content_without_title
    content_without_title=$(echo "$new_content" | tail -n +2)

    local escaped_old escaped_new
    escaped_old=$(printf '%s' "$old_content" | jq -Rs .)
    escaped_new=$(printf '%s' "$content_without_title" | jq -Rs .)

    local edit_response
    edit_response=$(call_mcp_with_context "edit-$FILENAME" "edit_note" \
      "{\"noteTitle\": $(printf '%s' "$note_identifier" | jq -Rs .), \"instruction\": \"Sync from local plan file\", \"old_content\": $escaped_old, \"new_content\": $escaped_new, \"skipLocalSync\": true}")

    echo "  Edit response: $edit_response" >> "$LOG_FILE"
}

# ========== 1순위: find_notes(localPlanPath) 매칭 ==========
ESCAPED_TITLE_JSON=$(printf '%s' "$TITLE" | jq -Rs .)

SEARCH_RESPONSE=$(call_mcp "find-$FILENAME" "find_notes" \
   "{\"localPlanPath\": \"$FILENAME\", \"limit\": 1}")

echo "  Search response: $SEARCH_RESPONSE" >> "$LOG_FILE"

EXISTING_NOTE_ID=$(echo "$SEARCH_RESPONSE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1 || echo "")

if [[ -n "$EXISTING_NOTE_ID" ]]; then
   echo "  [1순위] localPlanPath match: $EXISTING_NOTE_ID" >> "$LOG_FILE"
   update_note_content "$TITLE" "$CONTENT" "$EXISTING_NOTE_ID"
   echo "---" >> "$LOG_FILE"
   exit 0
fi

# ========== 2~3순위: 현재 노드 하위 노트 검색 ==========
# NODE_ID 없으면 → 3순위(자동 생성)로 직행
if [[ -z "${CONCLAVE_NODE_ID:-}" ]]; then
   echo "  [3순위] No NODE_ID, creating note" >> "$LOG_FILE"

  ESCAPED_CONTENT=$(printf '%s' "$CONTENT" | jq -Rs .)
  CREATE_RESPONSE=$(call_mcp_with_context "create-$FILENAME" "create_note" \
    "{\"title\": $ESCAPED_TITLE_JSON, \"content\": $ESCAPED_CONTENT, \"localPlanPath\": \"$FILENAME\"}")

  echo "  Create response: $CREATE_RESPONSE" >> "$LOG_FILE"
  echo "---" >> "$LOG_FILE"
  exit 0
fi

# NODE_ID는 있지만 NODE_TYPE이 없으면 → 동적 해석 시도
if [[ -z "${CONCLAVE_NODE_TYPE:-}" ]]; then
  echo "  [RESOLVE] NODE_TYPE missing, attempting to resolve from NODE_ID=$CONCLAVE_NODE_ID" >> "$LOG_FILE"
  RESOLVED_TYPE=$(resolve_node_type "$CONCLAVE_NODE_ID")
  
  if [[ -n "$RESOLVED_TYPE" ]]; then
    echo "  [RESOLVE] Successfully resolved NODE_TYPE=$RESOLVED_TYPE" >> "$LOG_FILE"
    CONCLAVE_NODE_TYPE="$RESOLVED_TYPE"
   else
     echo "  [RESOLVE] Failed to resolve NODE_TYPE, delegating to AI (2순위)" >> "$LOG_FILE"
     # 2순위로 fallback (아래 코드 참고)
   fi
fi

# NODE_TYPE 해석 실패 시 2순위로 직행
if [[ -z "${CONCLAVE_NODE_TYPE:-}" ]]; then
   echo "  [2순위] NODE_TYPE unresolved, delegating to AI" >> "$LOG_FILE"
  
  CONTEXT_MSG="[Plan Sync] Plan file '$FILENAME' was saved locally but NODE_TYPE could not be resolved. Please verify the NODE_ID and try again, or manually create/edit a note."
  
  cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"$CONTEXT_MSG"}}
EOF
  
  echo "---" >> "$LOG_FILE"
  exit 0
fi

# NODE_ID가 있으면 해당 노드 하위 노트 직접 검색
NODE_PATH_TYPE="${CONCLAVE_NODE_TYPE}s"
ALL_NOTES=""

CHILDREN_RESPONSE=$(call_mcp "list-children" "list_tree" \
  "{\"path\": \"/${NODE_PATH_TYPE}/${CONCLAVE_NODE_ID}/children\", \"limit\": 50}")
echo "  list_tree path: /${NODE_PATH_TYPE}/${CONCLAVE_NODE_ID}/children" >> "$LOG_FILE"

# 직접 하위 노트
DIRECT_NOTES=$(extract_notes "$CHILDREN_RESPONSE")
if [[ -n "$DIRECT_NOTES" ]]; then
  ALL_NOTES="$DIRECT_NOTES"
fi

# 하위 agent_session들의 노트도 수집
CHILDREN_TEXT=""
if echo "$CHILDREN_RESPONSE" | jq -e '.result.content[0].text' > /dev/null 2>&1; then
  CHILDREN_TEXT=$(echo "$CHILDREN_RESPONSE" | jq -r '.result.content[0].text // ""')
fi

SESSION_IDS=$(echo "$CHILDREN_TEXT" | grep '\[agent_session\]' | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' || true)
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

NOTE_COUNT=$(echo "$ALL_NOTES" | grep -c '\[note\]' || echo 0)
echo "  Parent notes found: $NOTE_COUNT" >> "$LOG_FILE"

if [[ "$NOTE_COUNT" -eq 0 || -z "$ALL_NOTES" ]]; then
   # ========== 3순위: 노트 전무 → 자동 생성 ==========
   echo "  [3순위] No notes under parent, creating new note" >> "$LOG_FILE"

   ESCAPED_CONTENT=$(printf '%s' "$CONTENT" | jq -Rs .)
   CREATE_RESPONSE=$(call_mcp_with_context "create-$FILENAME" "create_note" \
     "{\"title\": $ESCAPED_TITLE_JSON, \"content\": $ESCAPED_CONTENT, \"localPlanPath\": \"$FILENAME\"}")

   echo "  Create response: $CREATE_RESPONSE" >> "$LOG_FILE"
   echo "---" >> "$LOG_FILE"
   exit 0
fi

# ========== 2순위: 노트 있지만 localPlanPath 불일치 → additionalContext로 AI에게 위임 ==========
echo "  [2순위] Notes exist but localPlanPath not set, delegating to AI" >> "$LOG_FILE"

NOTE_LIST=""
while IFS= read -r line; do
   if [[ -n "$line" ]]; then
     NOTE_LIST="${NOTE_LIST}\\n- ${line}"
   fi
done <<< "$ALL_NOTES"

CONTEXT_MSG="[Plan Sync] Plan file '$FILENAME' was saved locally but NOT synced to Conclave yet. Existing notes found under parent:${NOTE_LIST}\\n\\nAction required: If your plan covers the same topic as one of these notes, call edit_note to update it and set local_plan_path='$FILENAME'. If this is a new topic, call create_note with localPlanPath='$FILENAME'. If a note already has a different localPlanPath set, decide whether to overwrite it or create a new note."

cat <<EOF
{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"$CONTEXT_MSG"}}
EOF

echo "---" >> "$LOG_FILE"
exit 0
