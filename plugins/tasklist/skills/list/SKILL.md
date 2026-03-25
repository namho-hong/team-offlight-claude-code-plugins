---
name: list
description: |
  저장된 Task List 목록과 진행률을 조회합니다.
  Trigger: "/tasklist:list", "어떤 태스크 리스트 있어?", "태스크 리스트 목록"
model: haiku
allowed-tools:
  - Bash
user-invocable: true
---

# Task List — 목록 조회

`~/.claude/tasks/`에 저장된 Task List를 진행률과 함께 표시합니다.

## 실행

단일 Bash 호출로 UUID 디렉토리를 제외하고 이름 있는 리스트만 출력합니다:

```bash
python3 -c "
import json, os, glob, re
base = os.path.expanduser('~/.claude/tasks')
dirs = sorted([d for d in os.listdir(base)
               if os.path.isdir(os.path.join(base, d))
               and not re.match(r'^[0-9a-f]{8}-', d)])
for i, name in enumerate(dirs, 1):
    path = os.path.join(base, name)
    files = glob.glob(os.path.join(path, '*.json'))
    total = len(files)
    if total == 0:
        continue
    done = 0; prog = 0; pend = 0
    for f in files:
        try:
            s = json.load(open(f)).get('status','')
            if s == 'completed': done += 1
            elif s == 'in_progress': prog += 1
            elif s == 'pending': pend += 1
        except: pass
    print(f'  {i:2d}) {name:<35s} {done}/{total} done, {prog} in progress, {pend} pending')
"
```

결과를 그대로 표시하고 끝. 로드하려면 `/tasklist:load <이름>`을 안내한다.
