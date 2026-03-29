#!/bin/bash
# Play a sound when Claude stops responding
# Conclave 터미널에서는 스킵 (별도 훅이 처리)

if [[ -n "${CONCLAVE_TERMINAL:-}" ]]; then
  exit 0
fi

# stdin 소비 (Stop 훅은 stdin으로 JSON 받음)
cat > /dev/null

# 사운드 재생
afplay /System/Library/Sounds/Glass.aiff </dev/null >/dev/null 2>&1 &
disown

exit 0
