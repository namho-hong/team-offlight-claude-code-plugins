#!/bin/bash
# Show a macOS notification when Claude stops responding
# Conclave 터미널에서는 스킵 (별도 훅이 처리)

if [[ -n "${CONCLAVE_TERMINAL:-}" ]]; then
  exit 0
fi

# stdin에서 Stop 훅 데이터 읽기
HOOK_INPUT=$(cat)
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)

# transcript에서 마지막 assistant 메시지 추출
BODY="Response complete"
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
  LAST_MSG=$(grep '"type":"assistant"' "$TRANSCRIPT_PATH" | tail -1 | jq -r '.message.content[-1].text // empty' 2>/dev/null)
  if [[ -n "$LAST_MSG" ]]; then
    BODY=$(echo "$LAST_MSG" | head -c 200)
  fi
fi

# macOS 네이티브 알림
osascript -e "display notification \"$BODY\" with title \"Claude Code\"" &

exit 0
