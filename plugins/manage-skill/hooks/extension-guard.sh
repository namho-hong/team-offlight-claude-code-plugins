#!/bin/bash
# PreToolUse hook: 확장 파일(skill/hook/agent) 수정 시 manage-skill 스킬 사용 강제
# Matcher: Edit|Write

input=$(cat)
file_path=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# manage-skill이 활성화되어 있으면 통과
LOCK_FILE="/tmp/manage-skill-active"
if [[ -f "$LOCK_FILE" ]]; then
  lock_age=$(( $(date +%s) - $(stat -f %m "$LOCK_FILE") ))
  if [[ $lock_age -lt 1800 ]]; then
    exit 0
  fi
fi

# 확장 파일 패턴 체크
case "$file_path" in
  */claude-plugins/plugins/*/skills/*|*/claude-plugins/plugins/*/hooks/*|*/claude-plugins/plugins/*/agents/*|*/claude-plugins/plugins/*/.claude-plugin/*)
    ;;
  */.claude/skills/*|*/.claude/hooks/*|*/.claude/agents/*)
    ;;
  */claude-code-kit/skills/*|*/claude-code-kit/hooks/*|*/claude-code-kit/agents/*)
    ;;
  *)
    exit 0
    ;;
esac

echo "⛔ 확장 파일 수정이 차단되었습니다: $(basename "$file_path")"
echo "먼저 /manage-skill 스킬을 호출하세요."
echo "manage-skill이 검증 + 배포 파이프라인을 포함합니다."
exit 2
