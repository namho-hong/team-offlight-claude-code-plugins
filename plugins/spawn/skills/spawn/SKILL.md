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
2. Open a new Warp terminal tab via AppleScript
3. Paste and execute the command

## Intent → Command Mapping

Interpret the user's natural language request and build the appropriate command.
The spawned session is always **interactive** — the user will continue the conversation there.

| User says | Command |
|-----------|---------|
| "태스크 리스트 X로 세션 시작해줘" | `CLAUDE_CODE_TASK_LIST_ID=X claude` |
| "디버깅 세션 열어줘" | `claude --agent debugger` |
| "코드 리뷰 세션 띄워줘" | `claude --agent code-reviewer` |
| "애플워치 조사하는 세션 열어줘" | `claude` (user will type their prompt interactively) |
| "플러그인 테스트 세션" | `claude --plugin-dir ~/path` |
| "그냥 새 세션 하나 열어줘" | `claude` |

**NEVER use `-p` flag.** The user wants an interactive session, not a one-shot command.
If the user wants a specific topic, just start `claude` — they'll type the prompt themselves in the new session.

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
- NEVER use `claude -p` — always interactive sessions only

## After Spawning

Tell the user:
- What command was executed
- That the new session is ready in Warp

Do NOT try to interact with the spawned session. It's independent.
