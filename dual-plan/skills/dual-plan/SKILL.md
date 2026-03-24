---
name: dual-plan
description: Claude-Codex 계획 토론. 기존 플랜 파일을 Codex가 리뷰, Claude가 수정/반박. 합의까지 반복 (최대 10회).
argument-hint: "[plan-file.md] (생략 시 최신 플랜에서 선택)"
allowed-tools: Task, Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
disable-model-invocation: true
user-invocable: true
---

# Dual Plan

플랜 파일을 living document로 업데이트하며 Codex와 합의할 때까지 토론.

## Step 0: 플랜 파일 선택

- `$ARGUMENTS` 있으면 → `~/.claude/plans/$ARGUMENTS` 사용
- 없으면 → Glob(`~/.claude/plans/*.md`) 최신순 → 첫 `#` 헤딩 읽기 → AskUserQuestion 최대 4개 제시
- 파일 없으면 에러 후 종료

## Step 1: 토론 준비

1. 플랜 파일 끝에 `## Duel Status` (Round 0/10), `## 합의된 항목`, `## 미합의 쟁점`, `## 토론 로그` 추가
2. `mkdir -p /tmp/duel-$(date +%s)`

## Step 2: 토론 루프 (최대 10라운드)

1. **Codex 호출** — `references/prompts.md`의 템플릿 사용
   `codex exec --full-auto --ephemeral -o /tmp/{id}/round-{n}.txt "{prompt}"`
2. **결과 읽기** → `CONSENSUS:` 포함 시 Step 3으로
3. **Findings 판단** — **무조건 수용 금지. 독립 판단 + 증거 기반 근거 필수.**
   - 수용 → 플랜 수정 + 합의 항목 기록
   - 반박 → 코드/문서 증거 인용 + 토론 로그 기록
   - 부분 수용 → 대안 반영 + 사유 기록
4. **플랜 파일 업데이트** — Status, 합의, 쟁점, 로그 갱신
5. **사용자 보고** — 라운드 결과 테이블 출력
6. **다음 라운드** — 이전 해결 항목을 프롬프트에 포함 (재지적 방지)

## Step 3: 종료

- **합의 시**: Status→"합의 완료", 최종 보고 (라운드수, 합의건수, 플랜 경로)
- **10라운드 미합의**: 쟁점 정리표 (양쪽 입장+권장안) → AskUserQuestion으로 판단 요청 → 결과 반영
