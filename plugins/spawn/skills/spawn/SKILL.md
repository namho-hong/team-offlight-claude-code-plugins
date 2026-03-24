---
name: spawn
description: |
  Spawn a new Claude Code session in a Warp terminal tab.
  Trigger: "/spawn", "새 세션 띄워줘", "터미널 열어줘", "spawn",
  "새 탭에서 시작해줘", "별도 세션에서 해줘", "Warp에서 열어줘"
allowed-tools:
  - Bash
  - AskUserQuestion
---

# Spawn — Launch a new Claude Code session in Warp

Opens a new Warp terminal tab and starts an interactive Claude Code session.

## How It Works

1. Parse the user's intent into a `claude` CLI command
2. Build context prompt if the user wants a specific task
3. Open a new Warp terminal tab via AppleScript
4. Paste and execute the command

## Intent → Command Mapping

Interpret the user's natural language request and build the appropriate command.
The spawned session is always **interactive** — the user will continue the conversation there.

| User says | Command |
|-----------|---------|
| "태스크 리스트 X로 세션 시작해줘" | `CLAUDE_CODE_TASK_LIST_ID=X claude` |
| "디버깅 세션 열어줘" | `claude --agent debugger` |
| "코드 리뷰 세션 띄워줘" | `claude --agent code-reviewer` |
| "그냥 새 세션 하나 열어줘" | `claude` |
| "이 작업 새 세션에서 해줘" | `claude $'작업 맥락과 지시사항'` |

## Context Passing

새 세션에 작업 맥락을 전달해야 할 때, **반드시 $'...' (ANSI-C quoting)을 사용**한다.

```bash
claude $'작업 배경과 지시사항.\n\n해야 할 것:\n1. 첫 번째\n2. 두 번째'
```

**규칙:**
- `-p` 금지 — one-shot 모드라 세션이 바로 종료됨
- `--append-system-prompt` 금지 — 유저 프롬프트가 없으면 Claude가 동작 안 함
- `"..."` 대신 `$'...'` 사용 — Conclave 내부 터미널에서 `"..."`로 전달하면 MCP config 경로로 오해석되는 이슈 있음
- 맥락이 있으면 반드시 전달 — 빈 세션을 띄우고 유저에게 알아서 입력하라고 하지 말 것
- 맥락에는 **왜 이 작업을 해야 하는지, 배경, 관련 파일 위치, 해야 할 것**을 포함

**맥락이 필요 없는 경우만** `claude` 단독 실행:
- "그냥 새 세션 하나 열어줘"
- 특정 작업 없이 빈 세션을 원할 때

If the intent is ambiguous, ask the user to clarify using AskUserQuestion.

Multiple flags can be combined:
```bash
CLAUDE_CODE_TASK_LIST_ID=my-tasks claude --agent debugger
```

## Execution

**NON-NEGOTIABLE: Use this exact AppleScript pattern. Do NOT modify it.**

```bash
osascript -e '
set the clipboard to "<COMMAND_HERE>"
tell application "System Events"
    tell process "stable"
        click menu item "New Terminal Tab" of menu "File" of menu bar 1
        delay 3
        click menu item "Paste" of menu "Edit" of menu bar 1
        delay 1
        keystroke return
    end tell
end tell
'
```

**CRITICAL rules:**
- Warp's process name is `"stable"`, NOT `"Warp"`
- Use `Edit > Paste` menu click, NOT `keystroke "v" using command down` (Cmd+V doesn't work in Warp)
- Use `File > New Terminal Tab` menu click, NOT `keystroke "t" using command down`
- delay 3 after opening tab (Warp needs time to initialize)
- Set clipboard BEFORE opening the tab
- The `keystroke return` at the end is REQUIRED — it submits the pasted command

## After Spawning

Tell the user:
- What command was executed
- That the new session is ready in Warp

Do NOT try to interact with the spawned session. It's independent.
