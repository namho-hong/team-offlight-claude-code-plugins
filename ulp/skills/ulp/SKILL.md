---
name: ulp
description: Ultimate Loop Planning - 복잡한 계획이 필요할 때 사용. 6단계 비판 기반 루프로 문제점 철저히 도출 후 플랜 생성. Use for deep planning, thorough analysis, complex feature design, or architecture decisions.
argument-hint: "<task description>"
allowed-tools: Task, WebSearch, Read, Glob, Grep, mcp__conclave-dev__create_note, mcp__conclave-dev__search_nodes, mcp__conclave-dev__read_task, mcp__conclave-dev__read_goal, mcp__conclave-dev__read_note
user-invocable: true
---

# Ultra Planning (ULP)

6단계 비판 기반 누적 루프. **Stop 훅이 자동으로 루프를 강제**합니다.

## 핵심 원칙

1. **실제 문제만** - 비판을 위한 비판 금지, 실패를 유발하는 문제만 다룸
2. **검증 기반 비판** - "이거 안 풀면 뭐가 실패하는가?"가 핵심 질문
3. **결과는 누적** - 이전 루프 결과를 유지하면서 개선

## 루프 구조

### Phase 1: Problem Discovery (Loop 1-4)

| Loop | 목표 | 출력 |
|------|------|------|
| 1 | Explore + WebSearch로 탐색 | Problems v1 |
| 2 | v1 검증 (실제 문제인가?) | Problems v2 |
| 3 | v2 검증 (원인인가 증상인가?) | Problems v3 |
| 4 | v3 최종 검토 + 분류 | Final Problems |

### Phase 2: Planning (Loop 5-6)

| Loop | 목표 | 출력 |
|------|------|------|
| 5 | Final Problems 기반 플랜 초안 | Plan v1 |
| 6 | Plan v1 검증 + 최종안 | Conclave Note |

## 동작 방식

1. `/ulp <task>` 호출 시 UserPromptSubmit 훅이 상태 파일 생성
2. 각 루프 완료 후 Stop 훅이 `decision: block` 반환
3. 다음 루프 지시가 reason으로 전달됨
4. Loop 6 완료 후 정상 종료

---

## Loop 1: Discovery

**Step 1: 요청 유형 파악**
- Bug fix / Problem solving
- Refactoring
- New feature implementation
- Design / Architecture decision
- Exploration / Learning
- Mixed (primary 선택, secondary 메모)

**Step 2: 유형별 문제 프레이밍**

| Type | 문제의 의미 |
|------|------------|
| Bug/Problem | 현재 뭐가 잘못 동작하는가, 재현 조건, 근본 원인 |
| Refactoring | 기술 부채, 유지보수 어려움, 확장성 제약 |
| New Feature | 사용자 페인포인트 + 구현 장애물 + 시스템 충돌 |
| Design/Architecture | 각 선택지의 단점, 리스크, 트레이드오프 |
| Exploration | 모르는 것, 조사가 필요한 것, 지식 갭 |

**Step 3: 탐색 & 출력**
- Task(Explore) 서브에이전트로 코드베이스 분석
- WebSearch로 베스트 프랙티스, 유사 사례 검색
- `## Problems v1` 출력

---

## Loop 2-4: 검증 기반 비판

각 문제에 대해 **3가지 검증 질문** 적용:

### 검증 체크리스트

| 질문 | No일 때 조치 |
|------|-------------|
| 1. 이거 안 풀면 뭐가 실패하는가? | 답 없으면 → 삭제 (실제 문제 아님) |
| 2. 이거 풀면 원래 목표에 도달하는가? | No면 → 삭제 (범위 벗어남) |
| 3. 이건 원인인가 증상인가? | 증상이면 → 원인으로 교체 |

### 각 루프 초점

- **Loop 2**: 질문 1 집중 - 실패를 유발하지 않는 문제 제거
- **Loop 3**: 질문 3 집중 - 증상 → 원인 변환
- **Loop 4**: 최종 정리 - 중복 제거, 우선순위 정렬

### 변경 없음 허용

실질적 개선점이 없으면:
```
## Problems vN
(v{N-1}과 동일 - 검증 결과 모든 문제가 유효함)
```

형식적 비판 금지. 억지로 문제 만들지 말 것.

---

## Loop 5: Plan Draft

Final Problems 각각에 대해:
- 해결 방안
- 구현 위치 (파일/모듈)
- 파일별 구체적 변경 사항 (추가/수정/삭제할 것)
- 실행 순서 및 의존성
- 검증 방법 (각 변경이 동작하는지 확인하는 방법)

`## Plan v1`으로 출력

---

## Loop 6: Finalize

**검증 질문:**
1. 이 플랜대로 하면 Final Problems가 전부 해결되는가?
2. 더 단순한 방법은 없는가?
3. 누가 봐도 질문 없이 구현 가능한가?

**플랜 형식**: 청사진만. 코드/설정/문서 내용 포함 금지.
- ✅ 무엇을, 어디서, 왜, 어떤 순서로

**Conclave Note 저장** (아래 별도 섹션 참조)

---

## Conclave Note 저장 방법

Loop 6 완료 후:

1. `search_nodes`로 관련 Goal/Task 검색
2. 연결 결정:
   - parent: 가장 관련성 높은 Goal (없으면 생략)
   - reference: 관련 Task/Note
3. `create_note` 호출 (parentNodeId, referenceNodeIds 포함)

---

## 사용 예시

```
/ulp 사용자 인증 시스템 리팩토링
/ulp MCP 서버에 새 도구 추가
/ulp 성능 최적화 전략
```
