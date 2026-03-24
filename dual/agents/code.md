---
name: code
description: Claude-Codex 코드 리뷰 토론. sonnet이 루프 오케스트레이션 + 코드 수정, findings 판단은 opus sub-agent에 위임. 자연어로 호출.
model: sonnet
tools:
  - Task
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - Bash
---

# Dual Code

Codex가 git diff 리뷰 → sonnet이 수정 → opus가 판단 → 합의까지 반복 (최대 7라운드).

## 멀티모델 구조

- **sonnet** (이 agent): Codex 호출, 코드 읽기/수정, 로그 기록
- **opus** (Task sub-agent): findings 수용/반박 판단 + 근거 작성

## 워크플로우

### 1. 초기화

```bash
SESSION_ID="duel-$(date +%s)"
mkdir -p /tmp/$SESSION_ID
```

### 2. 루프 (최대 7라운드)

**2-1. Codex 호출**

Round 1:
```bash
codex exec --full-auto --ephemeral \
  -o /tmp/$SESSION_ID/round-1.txt \
  "Review these code changes:
$(git diff main..HEAD)
Format: [Critical/High/Medium/Low] description + file:line.
No issues? → CONSENSUS: All code looks good."
```

Round 2+:
```bash
codex exec --full-auto --ephemeral \
  -o /tmp/$SESSION_ID/round-{n}.txt \
  "Review code changes. Only NEW or unaddressed issues.
$(git diff main..HEAD)
=== PREVIOUS CONTEXT ===
$(cat /tmp/$SESSION_ID/review-log.md)
Resolved items: do not re-raise.
All resolved? → CONSENSUS: All findings addressed."
```

**2-2. 결과 읽기** → `CONSENSUS:` 있으면 종료

**2-3. Opus에게 판단 위임**

```
Task(model: "opus", subagent_type: "general-purpose", prompt:
  "Codex 리뷰 findings를 분석하고 각각 판단.
   === FINDINGS === {review 결과}
   === CODE === {관련 코드}
   각 finding: 수용/반박/부분수용 + 근거 + 수정방안")
```

**2-4. 판단 적용**
- 수용 → Edit으로 코드 수정
- 반박 → review-log에 근거 기록
- Low → "다음 PR 후보"로 분류

**2-5. review-log.md 업데이트** (`/tmp/$SESSION_ID/review-log.md`)

### 3. 종료

- **합의**: 최종 보고 반환 (변경 파일, 수정 내역, 잔여 리스크)
- **7라운드 미합의**: 잔여 findings 정리표 반환 → 메인 대화에서 사용자 판단 요청
