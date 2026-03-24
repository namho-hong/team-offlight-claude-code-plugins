#!/bin/bash
# ULP Detector - UserPromptSubmit Hook
# /ulp 키워드 감지 → 상태 파일 생성

set -euo pipefail

HOOK_INPUT=$(cat)
PROMPT=$(echo "$HOOK_INPUT" | jq -r '.prompt // empty')
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

# 세션 ID 없으면 종료
if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

# /ulp로 시작하거나 !ulp 포함하는지 확인
if [[ "$PROMPT" == "/ulp"* ]] || [[ "$PROMPT" == *"!ulp"* ]]; then
  STATE_DIR="$HOME/.claude/ulp-state"
  mkdir -p "$STATE_DIR"
  STATE_FILE="$STATE_DIR/$SESSION_ID.json"

  # 이미 상태 파일이 있으면 스킵 (중복 방지)
  if [[ -f "$STATE_FILE" ]]; then
    exit 0
  fi

  # 원본 태스크 추출 (/ulp 또는 !ulp 제거)
  TASK=$(echo "$PROMPT" | sed 's/^\/ulp *//' | sed 's/!ulp *//')

  # 상태 파일 생성
  jq -n \
    --arg sid "$SESSION_ID" \
    --arg tp "$TRANSCRIPT_PATH" \
    --arg task "$TASK" \
    '{
      session_id: $sid,
      transcript_path: $tp,
      iteration: 1,
      max_iterations: 6,
      phase: "problem-discovery",
      original_task: $task,
      created_at: (now | todate)
    }' > "$STATE_FILE"

  # Claude에게 컨텍스트 전달
  cat << 'EOF'
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "ULP (Ultra Planning) MODE ACTIVATED - 6-Step Critical Loop\n\n## Loop 1: Discovery\n\n### Step 1: Identify Request Type\nFirst, determine what type of request this is:\n- Bug fix / Problem solving\n- Refactoring\n- New feature implementation\n- Design / Architecture decision\n- Exploration / Learning\n- Mixed (multiple types)\n\n### Step 2: Type-specific Problem Framing\n[Bug/Problem] Current behavior issues, reproduction conditions, root cause hypothesis\n[Refactoring] Technical debt, maintainability issues, scalability constraints\n[New Feature] Pain points from missing feature + implementation obstacles + conflicts with existing system\n[Design/Architecture] Downsides of each option, risks, trade-off analysis\n[Exploration] What's unknown, what needs investigation, knowledge gaps\n[Mixed] Pick primary type, note secondary aspects\n\n### Step 3: Output Guide by Type\n[Bug] Symptom, Reproduction, Impact, Root Cause Hypothesis\n[Refactoring] Current Pain, Technical Debt, Constraints\n[New Feature] Pain Point, Success Criteria, Implementation Obstacles, System Conflicts\n[Design] Options, Pros/Cons, Risks, Recommendation\n[Exploration] Known, Unknown, Investigation Plan\n\n### Step 4: Explore & Output\n1. Use Task(Explore) to analyze the codebase\n2. Use WebSearch for best practices\n3. Output type-appropriate '## Problems v1'\n\nIMPORTANT: The Stop hook will force you to continue to Loop 2 when you try to stop."
  }
}
EOF
fi

exit 0
