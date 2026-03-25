#!/bin/bash
# PostToolUse hook: ~/claude-plugins/ 파일 수정 시 배포 파이프라인 리마인더
# Matcher: Edit|Write

# tool_name과 input은 stdin으로 JSON 전달
input=$(cat)
file_path=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# ~/claude-plugins/ 하위 파일인지 확인
claude_plugins_dir="$HOME/claude-plugins"
if [[ "$file_path" == "$claude_plugins_dir"* ]]; then
  cat <<'REMINDER'
⚠️ 플러그인 파일이 수정되었습니다. 배포 파이프라인을 잊지 마세요:
1. cd ~/claude-plugins && git add -A && git commit && git push
2. cd ~/.claude/plugins/marketplaces/team-offlight && git pull
3. claude plugin install <name>@team-offlight
4. 사용자에게 /reload-plugins 안내
REMINDER
fi
