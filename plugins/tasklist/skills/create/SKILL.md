---
name: create
description: |
  태스크 리스트 생성 또는 기존 리스트에 태스크 추가. metadata(deadline, priority, category) 지원.
  Trigger: "/tasklist:create", "태스크 리스트 만들어", "태스크 추가해",
  "task list 만들어", "할 일 추가"
allowed-tools:
  - Bash
  - AskUserQuestion
user-invocable: true
---

# Task List — 생성/추가

`~/.claude/tasks/`에 태스크 리스트를 생성하거나 기존 리스트에 태스크를 추가합니다.

## 메타데이터 컨벤션

| 필드 | 타입 | 설명 | 예시 |
|------|------|------|------|
| `deadline` | ISO date | 마감일 | `2026-03-25` |
| `priority` | enum | 중요도 | `high`, `medium`, `low` |
| `category` | string | 분류 | `finance`, `legal`, `meeting`, `dev` |

메타데이터는 선택 사항. 사용자가 언급하지 않으면 생략한다.
단, 문맥에서 추론 가능하면 자동으로 채운다:
- "오늘까지" → `deadline: <오늘 날짜>`
- "급한" / "중요한" → `priority: high`

## Step 1: 리스트 이름 결정

`$ARGUMENTS`에 리스트 이름이 있으면 사용. 없으면 질문한다.

기존 리스트에 추가할지, 새로 만들지 판단:
```bash
ls ~/.claude/tasks/ | grep -v '^[0-9a-f]\{8\}-'
```

## Step 2: 태스크 항목 파싱

사용자가 제공한 항목들에서 추출:
- **subject**: 태스크 제목
- **description**: 상세 설명 (없으면 subject와 동일)
- **metadata**: deadline, priority, category (문맥에서 추론)
- **blockedBy**: 의존 관계 (사용자가 명시한 경우만)

## Step 3: 생성

```bash
mkdir -p ~/.claude/tasks/<list-name>
python3 -c "
import json, os

base = os.path.expanduser('~/.claude/tasks/<list-name>')
# 기존 태스크 ID 이어서 번호 매기기
existing = [int(f.split('.')[0]) for f in os.listdir(base) if f.endswith('.json')]
next_id = max(existing) + 1 if existing else 1

tasks = [
    # (subject, description, metadata_dict, blocked_by_list)
]

for i, (subj, desc, meta, blocked) in enumerate(tasks):
    tid = str(next_id + i)
    task = {
        'id': tid,
        'subject': subj,
        'description': desc,
        'status': 'pending',
        'blocks': [],
        'blockedBy': blocked,
    }
    if meta:
        task['metadata'] = meta
    with open(os.path.join(base, f'{tid}.json'), 'w') as f:
        json.dump(task, f, indent=2, ensure_ascii=False)
    print(f'  ✓ {tid}. {subj}')
"
```

## Step 4: 결과 표시

생성된 태스크를 마크다운 테이블로 표시:

| # | Task | Deadline | Priority | Category |
|---|------|----------|----------|----------|
| 1 | example | 2026-03-25 | high | finance |

메타데이터가 없는 컬럼은 `-`로 표시.
