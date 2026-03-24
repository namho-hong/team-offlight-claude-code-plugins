#!/bin/bash
# ULP Loop - Stop Hook
# 6단계 루프 강제 실행

set -euo pipefail

HOOK_INPUT=$(cat)
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty')

# 세션 ID 없으면 종료
if [[ -z "$SESSION_ID" ]]; then
  exit 0
fi

STATE_DIR="$HOME/.claude/ulp-state"
STATE_FILE="$STATE_DIR/$SESSION_ID.json"

# ULP 상태 파일 없으면 일반 종료
if [[ ! -f "$STATE_FILE" ]]; then
  exit 0
fi

# 상태 읽기
ITERATION=$(jq -r '.iteration' "$STATE_FILE")
MAX_ITERATIONS=$(jq -r '.max_iterations' "$STATE_FILE")

# 숫자 검증
if ! [[ "$ITERATION" =~ ^[0-9]+$ ]] || ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  rm -f "$STATE_FILE"
  exit 0
fi

# 최종 루프(6)면 종료 허용 + 상태 파일 삭제
if [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  rm -f "$STATE_FILE"
  echo '{"systemMessage": "ULP completed! 6 loops finished successfully."}'
  exit 0
fi

# 다음 iteration
NEXT_ITERATION=$((ITERATION + 1))

# 상태 업데이트
jq --argjson iter "$NEXT_ITERATION" '.iteration = $iter' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

# 루프별 reason 메시지
case $NEXT_ITERATION in
  2)
    REASON="LOOP 1 COMPLETE. Starting Loop 2.

## Loop 2: Critique v1

### Type-specific Critique Points
[Bug] Is reproduction specific? Is hypothesis testable?
[Refactoring] Is debt real or premature optimization?
[New Feature] Is pain point from user perspective? Are success criteria measurable?
[Design] Did you consider all reasonable options? Long-term impact evaluated?
[Exploration] Are unknowns truly unknown or just uninvestigated?

### General Critique
- Did you pick the right request type?
- Missing problems you overlooked?
- Incorrectly defined problems?
- Scope issues (too broad or too narrow)?
- Wrong assumptions?

Output '## Problems v2' that includes v1 items (keep/modify) + newly discovered problems."
    ;;
  3)
    REASON="LOOP 2 COMPLETE. Starting Loop 3.

## Loop 3: Critique v2
Review Problems v2 and find:
- Priority ordering issues
- Duplicates to merge
- Root cause vs symptom confusion
- Still missing edge cases

Output '## Problems v3' with improvements."
    ;;
  4)
    REASON="LOOP 3 COMPLETE. Starting Loop 4.

## Loop 4: Finalize Problems
Final review of v3:
- Remove duplicates
- Confirm priorities
- Categorize as Critical / Important / Nice-to-have

Output '## Final Problems List' with clear categories."
    ;;
  5)
    REASON="LOOP 4 COMPLETE. Starting Loop 5.

## Loop 5: Plan Draft
Based on Final Problems List, create a plan:
- Solution for each problem
- Implementation location (files/modules)
- Specific changes per file (what to add/modify/remove)
- Execution order with dependencies
- Verification method (how to confirm each change works)

Output '## Plan v1' with structured approach."
    ;;
  6)
    REASON="LOOP 5 COMPLETE. Starting Loop 6 (FINAL).

## Loop 6: Finalize Plan
Critique Plan v1:
- Weaknesses and gaps
- Missing edge cases
- Simpler alternatives
- Is plan specific enough? (Can someone implement without asking questions?)

Then output the FINAL PLAN."
    ;;
esac

# Block 반환 - Claude가 멈추지 못하고 계속 진행
jq -n --arg reason "$REASON" '{
  "decision": "block",
  "reason": $reason
}'

exit 0
