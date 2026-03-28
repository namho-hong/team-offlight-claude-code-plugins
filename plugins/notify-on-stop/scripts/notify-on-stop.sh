#!/bin/bash
# Play a sound and show a macOS notification when Claude stops responding
# Clicking the notification focuses the correct terminal tab
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

# --- TTY 해석: PPID 체인을 타고 올라가 Claude 프로세스의 TTY를 찾는다 ---
resolve_tty() {
  local pid=$$
  local max_depth=20
  local depth=0
  while [[ $depth -lt $max_depth ]]; do
    local ppid_val
    ppid_val=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ -z "$ppid_val" || "$ppid_val" == "0" || "$ppid_val" == "1" ]]; then
      return 1
    fi
    local comm tty_val
    comm=$(ps -o comm= -p "$ppid_val" 2>/dev/null | tr -d ' ')
    tty_val=$(ps -o tty= -p "$ppid_val" 2>/dev/null | tr -d ' ')
    if [[ "$comm" == *claude* && "$tty_val" != "??" && -n "$tty_val" ]]; then
      echo "/dev/$tty_val"
      return 0
    fi
    pid=$ppid_val
    depth=$((depth + 1))
  done
  return 1
}

# --- 터미널 설정 읽기 ---
CONFIG_FILE="$HOME/.claude/task-list-config.json"
TERMINAL_TYPE="terminal"
if [[ -f "$CONFIG_FILE" ]]; then
  TERMINAL_TYPE=$(jq -r '.terminal // "terminal"' "$CONFIG_FILE" 2>/dev/null)
fi

# --- 터미널별 Bundle ID ---
case "$TERMINAL_TYPE" in
  terminal) BUNDLE_ID="com.apple.Terminal" ;;
  iterm)    BUNDLE_ID="com.googlecode.iterm2" ;;
  ghostty)  BUNDLE_ID="com.mitchellh.ghostty" ;;
  warp)     BUNDLE_ID="dev.warp.Warp-Stable" ;;
  *)        BUNDLE_ID="com.apple.Terminal" ;;
esac

# --- TTY/CWD 해석 ---
TARGET_TTY=$(resolve_tty)
TARGET_CWD=$(pwd)

# --- 터미널별 포커스 AppleScript 생성 ---
build_focus_script() {
  local tty="$1"
  local cwd="$2"

  case "$TERMINAL_TYPE" in
    terminal)
      if [[ -n "$tty" ]]; then
        cat <<APPLESCRIPT
tell application "Terminal"
    repeat with w in windows
        repeat with t in tabs of w
            if tty of t is "$tty" then
                set frontmost of w to true
                set selected of t to true
                activate
                return
            end if
        end repeat
    end repeat
end tell
APPLESCRIPT
      fi
      ;;
    iterm)
      if [[ -n "$tty" ]]; then
        cat <<APPLESCRIPT
tell application "iTerm2"
    repeat with w in windows
        repeat with t in tabs of w
            repeat with s in sessions of t
                if tty of s is "$tty" then
                    select w
                    select t
                    select s
                    activate
                    return
                end if
            end repeat
        end repeat
    end repeat
end tell
APPLESCRIPT
      fi
      ;;
    ghostty)
      if [[ -n "$cwd" ]]; then
        cat <<APPLESCRIPT
tell application "Ghostty"
    repeat with w in windows
        repeat with t in tabs of w
            repeat with term in terminals of t
                if working directory of term is "$cwd" then
                    select tab t
                    activate window w
                    focus term
                    return
                end if
            end repeat
        end repeat
    end repeat
end tell
APPLESCRIPT
      fi
      ;;
    warp)
      # Warp has no AppleScript dictionary — just activate
      echo 'tell application "Warp" to activate'
      ;;
  esac
}

FOCUS_SCRIPT=$(build_focus_script "$TARGET_TTY" "$TARGET_CWD")

# --- 알림 전송 ---
if command -v terminal-notifier &>/dev/null && [[ -n "$FOCUS_SCRIPT" ]]; then
  # terminal-notifier: 알림 클릭 시 탭 포커스
  # -execute에 전달할 스크립트를 임시 파일로 저장 (복잡한 AppleScript를 인라인으로 넣기 어려움)
  FOCUS_SCRIPT_FILE=$(mktemp /tmp/notify-focus-XXXXXX.sh)
  echo '#!/bin/bash' > "$FOCUS_SCRIPT_FILE"
  echo "osascript <<'EOFSCRIPT'" >> "$FOCUS_SCRIPT_FILE"
  echo "$FOCUS_SCRIPT" >> "$FOCUS_SCRIPT_FILE"
  echo "EOFSCRIPT" >> "$FOCUS_SCRIPT_FILE"
  chmod +x "$FOCUS_SCRIPT_FILE"

  terminal-notifier \
    -message "$BODY" \
    -title "Claude Code" \
    -sender "$BUNDLE_ID" \
    -execute "$FOCUS_SCRIPT_FILE" &
elif command -v terminal-notifier &>/dev/null; then
  # terminal-notifier 있지만 포커스 스크립트 없음 (TTY 해석 실패 등)
  terminal-notifier \
    -message "$BODY" \
    -title "Claude Code" \
    -sender "$BUNDLE_ID" \
    -activate "$BUNDLE_ID" &
else
  # fallback: 기존 osascript 알림
  osascript -e "display notification \"$BODY\" with title \"Claude Code\"" &
fi

# 사운드 재생
afplay /System/Library/Sounds/Glass.aiff &

exit 0
