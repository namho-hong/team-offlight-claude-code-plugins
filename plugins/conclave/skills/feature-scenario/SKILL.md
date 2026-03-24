---
name: feature-scenario
description: 새 기능의 유저 시나리오를 대화로 완성하고, 기존 코드 패턴을 탐색해 기술 구현 계획까지 도출. Use when planning a new feature that needs user scenario definition and technical implementation plan.
argument-hint: "<feature description>"
allowed-tools: Agent, AskUserQuestion, Read, Glob, Grep, Bash, mcp__conclave-dev__create_note, mcp__conclave-dev__search_nodes, mcp__conclave-dev__read_task, mcp__conclave-dev__read_goal, mcp__conclave-dev__read_note
user-invocable: true
---

# Feature Scenario Skill

유저 시나리오 정의 → 기존 코드 탐색 → 기술 구현 계획 도출 → 구현 → `/simplify` 코드 정리까지 4단계로 진행하는 스킬.

## 핵심 원칙

1. **유저 시나리오 먼저** — 기술 구현 전에 "누가, 어디서, 무엇을, 왜" 하는지 확정
2. **기존 패턴 활용 극대화** — 새 패턴 도입 최소화, 기존 코드를 grep/read로 확인 후 동일 패턴 재사용
3. **AI 개발 친화성** — 추후 AI(Codex, Claude, Ralph) 세션이 혼란 없이 구현할 수 있는 명확한 계획

## Phase 1: 유저 시나리오 정의 (AskUserQuestion 루프)

### 1.1 현황 파악
- 관련 코드베이스를 Explore 에이전트로 탐색
- 현재 시스템의 데이터 흐름을 정리해서 사용자에게 보여줌
- 기존에 유사한 메커니즘이 있는지 확인

### 1.2 시나리오 질문 (2-3라운드)

**라운드 1: What & Where**
- 무엇을 하고 싶은가? (차단/필터/변경 등 핵심 액션)
- 어떤 단위로? (엔티티 레벨, 속성 레벨, 카테고리 레벨)
- 어디서 트리거? (UI 위치, 채팅, 설정 등 진입점)
- 되돌릴 수 있는가? (영구 vs 해제 가능)

**라운드 2: How (동작 상세)**
- 트리거 방식은? (자연어, 버튼, 키워드 등)
- 적용 후 동작은? (완전 무시, 조용히 처리, 알림만 끔 등)
- 피드백은? (확인 메시지, 상태 표시 등)

**라운드 3: Implementation Direction (기술 방향)**
- 저장 방식은? (기존 테이블 확장 vs 별도 테이블)
- 실행 메커니즘은? (tool call, API, 이벤트 등)
- 기존 코드 활용 가능한 패턴이 있는지 제시

### 1.3 시나리오 확정
- 위 질문 결과를 구조화된 시나리오로 정리
- 사용자 확인 후 Phase 2 진행

## Phase 2: 기존 코드 패턴 탐색

### 2.1 탐색 대상 (병렬 Explore 에이전트)

Phase 1에서 확정된 시나리오를 기반으로, 아래 영역을 병렬 탐색:

1. **데이터 레이어**: 관련 테이블 스키마, 마이그레이션 패턴, sync-rules
2. **실행 레이어**: 관련 기능의 현재 구현 (서비스, 핸들러, 디스패처)
3. **확장 패턴**: 유사한 기존 기능이 어떻게 추가되었는지 (tool 등록, 핸들러 패턴, preset 구조)

### 2.2 패턴 매칭

탐색 결과에서:
- **재사용 가능한 패턴** 식별 (예: tool 정의 패턴, handler 패턴, DB 변경 패턴)
- **변경이 필요한 파일** 목록화
- **격리 안전성 검증**: "기존 코드가 이 변경을 모르면 깨지는가?" (CLAUDE.md 격리 우선 원칙)

## Phase 3: 기술 구현 계획 도출

### 3.1 계획 구조 (CLAUDE.md plan-display.md 규칙 준수)

1. **주요 객체 설명**: 각 태스크를 ID + 한 줄 설명으로 나열
2. **관계 테이블**: 의존 관계, 병렬 가능 여부, 상태
3. **ASCII 구조도**: 태스크 간 의존 흐름을 시각화

### 3.2 기술 상세 (태스크별)

각 태스크에 대해:
- **변경 파일**: 정확한 파일 경로 + 라인 번호
- **변경 내용**: 기존 패턴을 참조한 구체적 코드 수준 설명
- **격리 검증**: 기존 코드 영향도 분석

### 3.3 안전성 체크리스트

CLAUDE.md의 Non-Negotiables 기준:
- [ ] DB 변경이 안전한 확장인가? (nullable, 기존 코드 무영향)
- [ ] PowerSync 4축 동기화 (schema.ts, migration, sync-rules, publication)
- [ ] Electron IPC 3점 동기화 필요 여부
- [ ] enum 값 변경/재정렬 없음
- [ ] 새 패턴 도입 없음 (기존 패턴 재사용)

### 3.4 AI 개발 친화성 검증

- [ ] 변경 포인트가 명확히 분리되어 있는가?
- [ ] grep으로 전체 흐름 추적 가능한 네이밍인가?
- [ ] 다른 AI 세션과 충돌할 수 있는 파일이 있는가?

## Phase 4: 구현 + `/simplify` (필수)

### 4.1 구현
- Phase 3 계획을 사용자 확인 후 구현
- `pnpm build` 통과 확인

### 4.2 `/simplify` 실행 (NON-NEGOTIABLE)
- 구현 완료 후 반드시 `/simplify` 스킬을 실행
- AI가 생성한 코드는 높은 확률로 중복, 비효율, 패턴 불일치를 포함함
- `/simplify`가 찾은 문제를 수정하고, 수정 후 다시 빌드 검증
- `/simplify` 통과 후에만 완료 보고

**이유:** 초안 코드를 그대로 커밋하면 다음 AI 세션이 잘못된 패턴을 학습/복제함.
copy-paste 중복, 불필요한 연산, 가독성 저하를 사전에 차단.

## 출력 형식

Phase 4 완료 후, 터미널에 아래를 출력:

1. **유저 시나리오 요약** (확정된 시나리오)
2. **구현 계획** (주요 객체 + 관계 테이블 + ASCII 구조도)
3. **태스크별 기술 상세**
4. **안전성 체크리스트 결과**

사용자 확인 후, Conclave Note로도 저장 (세션과 동일한 쓰레드 하위에 배치).

## 사용 예시

```
/feature-scenario Watcher 이메일 알림 중 특정 스레드 mute 기능
/feature-scenario Ghost 채팅방에서 파일 첨부 기능
/feature-scenario 캘린더 이벤트에서 자동 태스크 생성
```
