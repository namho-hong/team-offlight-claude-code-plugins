---
name: manage-skill
description: |
  Claude Code 확장(skill, hook, agent) 관리.
  신규 생성, 수정, 리네임, 삭제 + 배포 파이프라인.
  Trigger: "/manage-skill", "스킬 만들어", "훅 만들어", "에이전트 만들어",
  "확장 만들어", "확장 수정", "플러그인 리네임", "플러그인 리팩토링",
  "스킬 수정", "스킬 삭제", "플러그인 삭제",
  "create skill", "create hook", "create agent",
  "rename plugin", "refactor plugin", "delete plugin"
allowed-tools: AskUserQuestion, Read, Write, Edit, Bash, Glob, Grep
user-invocable: true
---

# Manage Skill

Claude Code 확장(skill, hook, agent)을 생성, 수정, 리네임, 삭제합니다.

## Step 1: 작업 유형 확인

사용자의 의도를 파악한다. 대화 맥락에서 명확하면 질문 없이 진행.

| 작업 | 분기 |
|------|------|
| **신규 생성** | Step 2 → 3 → 4 → 5 |
| **기존 수정** (스킬 내용 변경, 스킬 추가 등) | Step 3 (수정) → 4 → 5 (업데이트 파이프라인) |
| **리네임/리팩토링** (플러그인명 변경, 스킬 분리 등) | Step 1.5 → 2 → 3 → 4 → 5 + 정리 |
| **삭제** | Step 1.5 (정리만) |

확인할 것:
- 확장 유형 (skill / hook / agent)
- 기능 설명 (한 줄)

## Step 1.5: 구 확장 정리 (리네임/삭제 시)

마켓플레이스 플러그인인 경우, **반드시 모두 수행**:

```bash
# 1. 소스 삭제
rm -rf ~/claude-plugins/plugins/<old-name>/

# 2. marketplace.json에서 구 항목 제거
# (Edit 도구로 수행)

# 3. installed_plugins.json에서 구 항목 제거
python3 -c "
import json, os
path = os.path.expanduser('~/.claude/plugins/installed_plugins.json')
d = json.load(open(path))
key = '<old-name>@team-offlight'
if key in d['plugins']:
    del d['plugins'][key]
    json.dump(d, open(path, 'w'), indent=2, ensure_ascii=False)
    print(f'{key} 제거 완료')
"

# 4. 캐시 디렉토리 제거
rm -rf ~/.claude/plugins/cache/team-offlight/<old-name>/
```

프로젝트 `.claude/` 확장인 경우: 파일 삭제 + settings.json 훅 등록 해제.

삭제만이면 여기서 끝. 리네임이면 Step 2로 계속 진행.

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
