#!/bin/bash
# Play a system sound when Claude stops responding
# Conclave 터미널에서는 스킵 (별도 훅이 처리)

if [[ -n "${CONCLAVE_TERMINAL:-}" ]]; then
  exit 0
fi

# stdin 소비
cat > /dev/null

# 시스템 사운드 재생
afplay /System/Library/Sounds/Glass.aiff &

exit 0
