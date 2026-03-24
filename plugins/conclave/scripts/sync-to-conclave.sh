#!/bin/bash
# Claude Code ↔ Conclave 태스크 동기화 스크립트 v2
# TaskCreate, TaskUpdate 훅에서 호출됨

# Conclave 터미널이 아니면 그냥 통과
if [[ -z "${CONCLAVE_TERMINAL:-}" ]]; then
  exit 0
fi

# ========== 설정 ==========
MCP_URL="http://127.0.0.1:${CONCLAVE_MCP_PORT:-57537}/mcp"
MCP_TOKEN="${CONCLAVE_MCP_TOKEN:-}"
LOG_FILE="/tmp/conclave-sync.log"
MAP_FILE="/tmp/claude-conclave-task-map.json"  # ID 매핑 저장

# MCP 토큰 없으면 종료 (Conclave 연결 안 됨)
if [[ -z "$MCP_TOKEN" ]]; then
  exit 0
fi

# 매핑 파일 초기화 (없으면 생성)
if [[ ! -f "$MAP_FILE" ]]; then
    echo "{}" > "$MAP_FILE"
fi

# ========== stdin에서 JSON 읽기 ==========
INPUT_JSON=$(cat)

# ========== 도구 이름 확인 ==========
TOOL_NAME=$(echo "$INPUT_JSON" | jq -r '.tool_name')

# ========== TaskCreate: 새 태스크 생성 ==========
if [[ "$TOOL_NAME" == "TaskCreate" ]]; then

    # Claude Code 태스크 정보 추출
    CLAUDE_TASK_ID=$(echo "$INPUT_JSON" | jq -r '.tool_response.task.id')
    TASK_SUBJECT=$(echo "$INPUT_JSON" | jq -r '.tool_input.subject')
    TASK_DESC=$(echo "$INPUT_JSON" | jq -r '.tool_input.description // ""')

    echo "$(date): [CREATE] Claude #$CLAUDE_TASK_ID → Conclave" >> "$LOG_FILE"

    # Conclave에 태스크 생성
    RESPONSE=$(curl -s -X POST "$MCP_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $MCP_TOKEN" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"id\": \"create-$CLAUDE_TASK_ID\",
            \"method\": \"tools/call\",
            \"params\": {
                \"name\": \"create_task\",
                \"arguments\": {
                    \"name\": \"[Claude #$CLAUDE_TASK_ID] $TASK_SUBJECT\",
                    \"description\": \"$TASK_DESC\",
                    \"status\": \"in_progress\"
                }
            }
        }")

    # Conclave 태스크 ID 추출 (응답에서 파싱)
    # 응답 예: "Created task: \"[Claude #4] 제목\" (uuid)"
    # 간단하게 태스크 이름으로 나중에 검색하는 방식 사용

    echo "  Subject: $TASK_SUBJECT" >> "$LOG_FILE"
    echo "  Response: $RESPONSE" >> "$LOG_FILE"
    echo "---" >> "$LOG_FILE"
fi

# ========== TaskUpdate: 태스크 상태 변경 ==========
if [[ "$TOOL_NAME" == "TaskUpdate" ]]; then

    # Claude Code 태스크 정보 추출
    CLAUDE_TASK_ID=$(echo "$INPUT_JSON" | jq -r '.tool_input.taskId')
    NEW_STATUS=$(echo "$INPUT_JSON" | jq -r '.tool_input.status // ""')

    echo "$(date): [UPDATE] Claude #$CLAUDE_TASK_ID" >> "$LOG_FILE"
    echo "  New Status: $NEW_STATUS" >> "$LOG_FILE"

    # status가 completed면 Conclave에서도 완료 처리
    if [[ "$NEW_STATUS" == "completed" ]]; then

        # Conclave에서 해당 태스크 찾기 (이름으로 검색)
        SEARCH_RESPONSE=$(curl -s -X POST "$MCP_URL" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $MCP_TOKEN" \
            -d "{
                \"jsonrpc\": \"2.0\",
                \"id\": \"search-$CLAUDE_TASK_ID\",
                \"method\": \"tools/call\",
                \"params\": {
                    \"name\": \"find_tasks\",
                    \"arguments\": {
                        \"query\": \"[Claude #$CLAUDE_TASK_ID]\",
                        \"limit\": 1
                    }
                }
            }")

        echo "  Search: $SEARCH_RESPONSE" >> "$LOG_FILE"

        # UUID 추출 (응답에서 파싱)
        CONCLAVE_TASK_ID=$(echo "$SEARCH_RESPONSE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)

        if [[ -n "$CONCLAVE_TASK_ID" ]]; then
            # Conclave 태스크 완료 처리
            COMPLETE_RESPONSE=$(curl -s -X POST "$MCP_URL" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $MCP_TOKEN" \
                -d "{
                    \"jsonrpc\": \"2.0\",
                    \"id\": \"complete-$CLAUDE_TASK_ID\",
                    \"method\": \"tools/call\",
                    \"params\": {
                        \"name\": \"complete_task\",
                        \"arguments\": {
                            \"taskId\": \"$CONCLAVE_TASK_ID\"
                        }
                    }
                }")

            echo "  Completed: $COMPLETE_RESPONSE" >> "$LOG_FILE"
        else
            echo "  Error: Could not find Conclave task" >> "$LOG_FILE"
        fi
    fi

    echo "---" >> "$LOG_FILE"
fi
