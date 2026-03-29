---
name: ralph-plan
description: "Ralph Loop 실행을 위한 brief 문서를 생성합니다. 작업 유형별 인터뷰 → 검증 수단 설정 → brief 생성 → ralph-loop 실행까지."
argument-hint: "<태스크 설명>"
allowed-tools: AskUserQuestion, Read, Glob, Grep, Agent, Write, Edit, Bash
user-invocable: true
---

# Ralph Plan — Brief Generator for Ralph Loop

유저의 태스크 `$ARGUMENTS`를 인터뷰하고, 구멍 없는 brief 문서를 생성하여 `/ralph-loop`에 주입하는 스킬.

`$ARGUMENTS`가 비어있으면 Phase 1에서 태스크 설명을 질문한다.

## 핵심 원칙

1. **프롬프트는 짧게, 계획은 파일로** — ralph-loop에는 파일 참조만 주입, 상세 내용은 brief 문서에
2. **매 iteration 자기 복구** — brief 안의 Iteration Log로 컨텍스트 압축에도 상태 유지
3. **기계적 검증 가능한 완료 조건** — 사람이 아닌 컴퓨터가 판단할 수 있는 기준만 허용
4. **검증 도구 비종속** — Playwright 등 특정 도구에 하드코딩하지 않고, 프로젝트 환경을 탐색하여 제안
5. **컨텍스트 우선** — 대화에서 이미 아는 정보는 다시 묻지 않고 직접 추출. 빠진 부분만 질문
6. **검증은 증명 후 채택** — 검증 수단을 brief에 넣기 전에 실제로 동작하는지 선행 테스트 필수

## 공통 규칙

- AskUserQuestion 사용 시 반드시 **options 2개 이상** 제공 (도구 제약 사항)
- 유저에게 기술적 진단(실패 원인, 코드 분석)을 묻지 않는다 — 에이전트가 코드를 읽고 스스로 분석
- 유저에게는 증상, 기대 동작, 재현 조건 등 유저만 알 수 있는 것만 질문

## 생성 파일

- `.claude/ralph-brief-{slug}.md` — slug는 태스크 내용 기반 영문 자동 생성

---

## Phase 1: 작업 유형 분류

AskUserQuestion으로 유저에게 질문:

```
어떤 상황에서 Ralph를 돌리려는 건가요?

A. 간단한 버그 픽스
   단순한 수정 — 뭘 고칠지 알고 있고, 자동으로 돌리고 싶은 경우

B. 새 기능 개발
   기능 설계부터 필요 — 심도 있는 인터뷰로 빈틈 없는 계획서 생성

C. 반복 실패 중인 버그
   여러 번 시도했지만 계속 실패 — 이전 시도 이력을 정리하고 새 접근 유도
```

---

## Phase 2: 유형별 인터뷰

### A. 간단한 버그 픽스

가볍게 확인:
1. 뭘 수정하려는 건지?
2. 수정 후 어떤 상태면 성공인지?
3. 관련 파일/경로가 있으면 알려달라

→ 1라운드로 충분. 바로 Phase 3으로.

### B. 새 기능 개발 (심층 인터뷰)

빈 곳이 없을 때까지 반복 질문한다. 유저가 말하지 않은 부분을 찾아서 체크한다.

**라운드 1: What & Where**
- 무엇을 만드는가? (핵심 기능 한 줄 정의)
- 어떤 단위로 동작하는가? (엔티티, 속성, 카테고리 등)
- 어디서 트리거되는가? (UI 위치, 채팅, API, 이벤트 등)
- 되돌릴 수 있는가? (영구 vs 해제 가능)

**라운드 2: How (동작 상세)**
- 트리거 방식은? (버튼, 자연어, 키보드, 자동 등)
- 트리거 후 결과는? (UI 변경, 데이터 생성, 상태 전환 등)
- 유저에게 피드백은? (확인 메시지, 상태 표시, 알림 등)
- 에러 시 동작은? (롤백, 재시도, 에러 메시지 등)

**라운드 3: Edge Cases**
- 유저가 언급하지 않은 빈 곳을 능동적으로 찾는다
- "이 경우는 어떻게 동작해야 하나요?" 형태로 질문
- 동시성, 권한, 빈 데이터, 대량 데이터 등 고려
- 빈 곳이 없다고 판단될 때까지 추가 라운드 진행

**라운드 4: 기술 방향 (코드베이스 탐색 후)**
- Explore 에이전트로 관련 코드 탐색
- 기존 유사 패턴 발견 시 제안
- 새 패턴 도입 필요 시 명시
- 격리 안전성 확인 ("기존 코드가 이 변경을 모르면 깨지는가?")

### C. 반복 실패 중인 버그

**Step 1: 컨텍스트 자동 수집 (유저에게 묻기 전에 먼저)**

현재 대화 내용과 코드에서 아래 정보를 직접 추출한다:
- 버그 설명 (증상, 관련 파일/코드)
- 이전 시도 이력과 각 시도의 결과
- 현재 코드 상태
- 실패 원인 분석 (에이전트가 코드를 읽고 스스로 수행 — 유저에게 기술적 진단을 묻지 않는다)

추출한 내용을 유저에게 보여주고 **"이 정리가 맞는지?"** 확인만 받는다.
빠진 부분이 있을 때만 추가 질문한다.

**Step 2: 유저에게 묻는 것 (Step 1로 알 수 없는 것만)**
- 버그가 해결되었을 때 기대하는 정확한 동작
- 재현 조건 (유저만 아는 경우)

→ brief에 "이전 시도 이력" 섹션으로 들어가서, Ralph가 같은 실수를 반복하지 않도록 함.

---

## Phase 3: 검증 수단 설정

### 3.1 프로젝트 환경 자동 탐색

brief 생성 전에 프로젝트의 기존 테스트/E2E 인프라를 스캔한다:
- `package.json`의 scripts (test, e2e, playwright, cypress, vitest 등)
- 테스트 설정 파일 (playwright.config, cypress.config, jest.config, vitest.config 등)
- CI 설정 파일
- 기존 E2E 시나리오 파일

### 3.2 검증 방법 선택 (AskUserQuestion)

감지 결과를 함께 보여주며 질문:

```
완료 검증을 어떻게 할까요?
(프로젝트에서 {감지된 도구/스크립트} 가 감지되었습니다)

A. 빌드 + 린트만
   pnpm build && pnpm lint

B. 빌드 + 린트 + E2E ({감지된 도구명})
   위 + {감지된 E2E 명령어} 기반 시나리오 검증

C. 직접 입력
   다른 E2E 도구나 커스텀 검증 명령어를 직접 지정
```

### 3.3 검증 실현 가능성 선행 테스트

E2E 또는 자동화 검증을 선택한 경우, **brief 작성 전에 반드시** 아래를 수행한다:

1. **스텝 정의**: 검증 시나리오를 구체적 액션 단위로 분해
   예: "hover → 1초 대기 → 툴팁 등장 확인 → 스크롤 → 툴팁 사라짐 확인"

2. **도구 매핑**: 각 액션에 어떤 도구/API를 쓸지 명시
   예: "page.hover() → page.waitForTimeout(1100) → expect().toBeVisible() → element.scrollBy() → expect().not.toBeVisible()"

3. **선행 테스트**: 최소한의 스켈레톤 테스트를 실제로 실행하여 각 도구/API가 해당 시나리오에서 동작하는지 확인

4. **결과 보고**: 유저에게 "이 검증 방법이 실제로 동작함을 확인했습니다" 또는 "X 단계에서 Y 문제로 불가능합니다. 대안: Z"를 보고

**확인되지 않은 검증 방법은 brief에 포함하지 않는다.**

### 3.4 E2E 선택 시 추가 질문

- 어떤 화면에서 어떤 조작을 했을 때 어떤 결과가 나와야 하는지?
- 기존 시나리오 파일이 있으면 참조할 것인지?
- 새 시나리오를 생성할 것인지?

### 3.5 검증 기준 품질 체크

모든 완료 조건에 대해 자체 검증:
- "이 조건을 컴퓨터가 자동으로 판단할 수 있는가?" → No면 기준을 구체화하도록 유저에게 재질문
- 나이브한 기준("잘 동작하면", "에러 없으면") 금지 → 구체적 명령어 + 기대 결과로 변환

---

## Phase 4: Brief 생성

`.claude/ralph-brief-{slug}.md`를 아래 구조로 생성한다.
slug는 태스크 설명을 기반으로 영문 kebab-case로 자동 생성.

```markdown
# Ralph Brief: {제목}

## Type
{bug-fix | feature | persistent-bug}

## Goal
{구체적 요구사항 — 인터뷰 결과 종합}

## Done Criteria
- [ ] {검증 명령어 1} 통과
- [ ] {검증 명령어 2} 통과
- [ ] {기능/버그별 구체 조건}

## Verification
- Build: {빌드 명령어}
- Lint: {린트 명령어}
- E2E: {감지/입력된 E2E 명령어 — 선택 시}
  - Scenario: {시나리오 파일 경로 or 인라인 설명}

<!-- Type: feature 일 때만 -->
## User Scenario
{라운드 1~3 인터뷰 결과 구조화}

## Technical Direction
{라운드 4 코드베이스 탐색 결과}

<!-- Type: persistent-bug 일 때만 -->
## Previous Attempts
### Attempt 1: {접근법}
- Result: {실패 내용}
### Attempt 2: {접근법}
- Result: {실패 내용}

## Expected Behavior
{버그 해결 시 이상적 동작 형상}

## Reproduction Steps
{버그 재현 단계}

<!-- 공통 -->
## Phases
- [ ] Phase 1: {단계} — Verify: {검증 조건}
- [ ] Phase 2: {단계} — Verify: {검증 조건}

## Iteration Protocol
1. Read this file
2. Check current Phase and last Iteration Log entry
3. Run verification commands to assess current state
4. If errors exist → fix first. If clean → proceed to next work
5. When ALL Done Criteria are met, output: `<promise>DONE</promise>` (Ralph Loop의 stop hook은 이 태그만 감지함)

## Failure Rules
- Same error 3 times → log current approach in Iteration Log, switch strategy
- NEVER repeat a previously failed approach without a different angle
- If stuck after strategy switch → log blocker and continue to next Phase

## Iteration Log
<!-- Append per iteration. Do NOT delete previous entries. -->
```

---

## Phase 5: 확인 및 실행

1. 생성된 brief를 유저에게 보여준다
2. 수정 요청이 있으면 반영한다
3. 확정되면 아래 명령어를 제시하고, 유저 확인 후 실행:

```bash
/ralph-loop "Read .claude/ralph-brief-{slug}.md and follow the instructions. Record each iteration in the Iteration Log section." --max-iterations {유형별 적절한 수} --completion-promise "DONE"
```

max-iterations 기본값:
- A. 간단한 버그 픽스: 15
- B. 새 기능 개발: 40
- C. 반복 실패 중인 버그: 25
