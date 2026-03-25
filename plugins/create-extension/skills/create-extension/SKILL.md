---
name: create-extension
description: |
  Claude Code 확장(skill, hook, agent) 생성 가이드.
  올바른 배치 위치를 판단하고 파일을 생성합니다.
  Trigger: "/create-extension", "스킬 만들어", "훅 만들어", "에이전트 만들어",
  "확장 만들어", "create skill", "create hook", "create agent"
allowed-tools: AskUserQuestion, Read, Write, Edit, Bash, Glob, Grep
user-invocable: true
---

# Create Extension

Claude Code 확장(skill, hook, agent)을 올바른 위치에 생성합니다.

## Step 1: 무엇을 만드는지 확인

사용자에게 질문:
- 무엇을 만드려는가? (skill / hook / agent)
- 어떤 기능을 하는가? (한 줄 설명)

## Step 2: 배치 위치 판단

아래 의사결정 트리를 따라 위치를 결정합니다.

```
Conclave 관련인가? (mcp__conclave-dev__* 사용, CONCLAVE_TERMINAL 의존, Conclave 앱 기능)
│
├─ NO → 마켓플레이스 (team-offlight)
│        위치: ~/claude-plugins/plugins/<name>/
│        설치: claude plugin install <name>@team-offlight
│        특징: 어떤 프로젝트에서든 사용 가능, 자동 업데이트
│
└─ YES → 누구를 위한 건가?
          │
          ├─ 앱 사용자 → claude-code-kit (앱 내장)
          │   위치: apps/desktop/resources/claude-code-kit/
          │   특징: 앱 시작 시 ~/.claude/에 자동 설치
          │   훅은 hookInstaller.ts HOOK_CONFIGS에 등록 필수
          │   모든 훅에 CONCLAVE_TERMINAL 가드 필수
          │
          └─ 개발팀 → 프로젝트 .claude/
              위치: .claude/skills/, .claude/hooks/, .claude/agents/
              특징: git pull로 팀원 동기화
```

판단 결과를 사용자에게 보고하고 확인받습니다:
- 배치 위치
- 이유

## Step 3: 생성

### Skill 생성

```
<위치>/skills/<name>/SKILL.md
```

SKILL.md 필수 frontmatter:
```yaml
---
name: <name>
description: <한 줄 설명>
allowed-tools: <필요한 도구 목록>
user-invocable: true
---
```

### Hook 생성

**claude-code-kit 훅인 경우:**
1. `apps/desktop/resources/claude-code-kit/hooks/<name>.sh` 생성
2. `hookInstaller.ts`의 `HOOK_CONFIGS`에 추가:
   ```typescript
   { path: '<name>.sh', eventType: '<event>', matcher: '<matcher>' }
   ```
3. 스크립트 첫 줄에 CONCLAVE_TERMINAL 가드 추가:
   ```bash
   if [[ -z "${CONCLAVE_TERMINAL:-}" ]]; then
     exit 0
   fi
   ```

**프로젝트 훅인 경우:**
1. `.claude/hooks/<name>.sh` 생성
2. `.claude/settings.json`의 hooks에 등록

### Agent 생성

```
<위치>/agents/<name>.md
```

Agent .md 필수 frontmatter:
```yaml
---
name: <name>
description: <한 줄 설명>
model: <sonnet|opus|haiku>
tools:
  - <도구 목록>
---
```

### 마켓플레이스 플러그인 생성

1. `~/claude-plugins/plugins/<name>/` 디렉토리 생성
2. `.claude-plugin/plugin.json` 생성:
   ```json
   {
     "name": "<name>",
     "version": "1.0.0",
     "description": "<설명>",
     "author": { "name": "Team Offlight", "url": "https://github.com/offlightinc" },
     "repository": "https://github.com/offlightinc/claude-plugins",
     "license": "MIT"
   }
   ```
3. skills/, agents/, hooks/ 하위에 파일 배치
4. `~/claude-plugins/.claude-plugin/marketplace.json`의 plugins 배열에 추가
5. git commit + push

## Step 4: 검증

- 파일이 올바른 위치에 생성되었는지 확인
- frontmatter가 유효한지 확인
- 마켓플레이스인 경우 marketplace.json에 등록되었는지 확인
- claude-code-kit 훅인 경우 hookInstaller.ts에 등록되었는지 확인
- MCP 의존이 있는데 마켓플레이스에 넣으려 한 건 아닌지 재확인

## Step 5: 배포 & 활성화

**파일 생성 ≠ 배포 완료.** 배치 유형별로 활성화 단계가 다르다.

### 마켓플레이스 (team-offlight)

5단계 파이프라인을 **전부 실행**해야 사용 가능:

```bash
# 1. 커밋
cd ~/claude-plugins
git add plugins/<name>/ .claude-plugin/marketplace.json
git commit -m "feat: <name> 플러그인 추가"

# 2. Push
git push

# 3. 로컬 마켓플레이스 캐시 갱신 (이걸 빠뜨리면 install 시 "not found")
cd ~/.claude/plugins/marketplaces/team-offlight
git pull

# 4. 플러그인 설치
claude plugin install <name>@team-offlight

# 5. 현재 세션에 반영 — 자동화 불가, 반드시 안내
```

Step 1~4는 Bash로 자동 실행한다. Step 5는 빌트인 CLI 명령어라 도구로 호출 불가.
**모든 배치 유형에서, 배포 완료 후 반드시 사용자에게 다음을 말한다:**

> `/reload-plugins` 를 입력하시면 현재 세션에 바로 반영됩니다.

이 안내를 빠뜨리면 사용자가 "안 되는데?" 하게 된다. 반드시 말한다.

### 마켓플레이스 플러그인 업데이트 (기존 플러그인 수정 시)

이미 설치된 플러그인을 수정한 경우, marketplace git pull만으로는 **캐시가 갱신되지 않는다**.
`claude plugin install`을 다시 실행해야 캐시가 최신 커밋으로 교체된다.

```bash
# 1~3은 신규와 동일 (commit → push → marketplace git pull)

# 4. 재설치 (캐시 덮어쓰기)
claude plugin install <name>@team-offlight

# 5. /reload-plugins 안내 (동일)
```

**흔한 실패 원인:**
- push 후 바로 install → 캐시 stale → **"Plugin not found"** → marketplace git pull 누락
- install 후 스킬이 안 보임 → `/reload-plugins` 안 했음
- 기존 플러그인 수정 후 marketplace git pull만 함 → **캐시는 설치 시점 커밋에 고정** → 재설치 필요

### 프로젝트 .claude/

- 파일 생성 즉시 사용 가능 (다음 세션 또는 `/reload-plugins`)
- git commit은 팀 공유 목적으로 별도 수행
- **배포 완료 후 `/reload-plugins` 안내 필수** (위와 동일)

### claude-code-kit

- 앱 빌드(`pnpm --filter=@conclave/desktop build:mac`) 후 hookInstaller가 자동 설치
- 개발 중에는 수동으로 `~/.claude/`에 복사하여 테스트 가능

## 금지 사항

- MCP 의존(`mcp__conclave-dev__*`) 있는 확장을 마켓플레이스에 넣지 않는다
- 글로벌 `~/.claude/skills/` 또는 `~/.claude/agents/`에 직접 생성하지 않는다 (hookInstaller/skillInstaller 또는 마켓플레이스를 통해서만)
- hookInstaller에 등록하지 않고 claude-code-kit 훅만 파일로 넣지 않는다
