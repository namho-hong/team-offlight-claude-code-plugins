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

## Step 0: 가드 해제

확장 파일 수정 전에 반드시 실행한다. PreToolUse 훅이 확장 파일 Edit/Write를 차단하므로, 락 파일로 우회한다.

```bash
touch /tmp/manage-skill-active
```

**작업 완료 후 반드시 Step 6에서 해제한다.**

## Step 1: 작업 유형 확인

사용자의 의도를 파악한다. 대화 맥락에서 명확하면 질문 없이 진행.

| 작업 | 분기 |
|------|------|
| **신규 생성** | Step 2 → 3 → 4 → 5 |
| **기존 수정** (스킬 내용 변경, 스킬 추가 등) | Step 3 (수정) → 4 → 5 (업데이트) |
| **리네임/리팩토링** (플러그인명 변경, 스킬 분리 등) | Step 1.5 → 2 → 3 → 4 → 5 |
| **삭제** | Step 1.5 |

확인할 것:
- 확장 유형 (skill / hook / agent)
- 기능 설명 (한 줄)

## Step 1.5: 구 확장 제거 (리네임/삭제 시)

### 마켓플레이스 플러그인

`claude plugin uninstall`이 installed_plugins.json + settings.json + 캐시를 **자동 정리**한다.
수동으로 JSON 편집하거나 캐시 디렉토리를 삭제하지 않는다.

**scope에 따라 플래그가 다르다:**
- user scope (글로벌): `claude plugin uninstall <name>@<marketplace>`
- project scope: `claude plugin uninstall <name>@<marketplace> --scope project`

project scope에서 enabled된 플러그인은 `--scope project` 없이 uninstall 불가.
에러 "enabled at project scope"가 나오면 `--scope project`를 붙인다.

```bash
# 1. 제거 (캐시 + settings 자동 정리)
claude plugin uninstall <old-name>@team-offlight
# project scope인 경우:
claude plugin uninstall <old-name>@team-offlight --scope project

# 2. 소스 삭제
rm -rf ~/claude-plugins/plugins/<old-name>/

# 3. marketplace.json에서 구 항목 제거
# (Edit 도구로 수행)
```

### 프로젝트 .claude/ 확장

파일 삭제 + settings.json 훅 등록 해제.

삭제만이면 여기서 끝. 리네임이면 Step 2로 계속.

## Step 2: 배치 위치 판단 (인터뷰)

**혼자 판단하지 않는다.** 반드시 사용자에게 질문하여 확인받는다.

### 2-1. 질의응답 (AskUserQuestion 사용)

AskUserQuestion 도구로 선택지를 제시한다. 대화 맥락에서 이미 답이 나온 항목은 생략 가능.

**질문 1:**
```
AskUserQuestion(
  question: "이 확장이 Conclave(MCP, CONCLAVE_TERMINAL 등)에 의존하나요?",
  options: [
    "NO — Conclave 무관, 범용",
    "YES — Conclave MCP/환경변수 사용"
  ]
)
```
- "NO" → 마켓플레이스 (team-offlight) 확정 → 2-2로
- "YES" → 질문 2로

**질문 2 (Conclave 관련인 경우):**
```
AskUserQuestion(
  question: "이 확장은 누구를 위한 건가요?",
  options: [
    "앱 사용자 — claude-code-kit에 내장",
    "개발팀 — 프로젝트 .claude/에 배치"
  ]
)
```

### 2-2. 판단 결과 제시 + 확인

질의응답 결과를 바탕으로, AskUserQuestion으로 최종 확인을 받는다:

```
AskUserQuestion(
  question: "배치 위치: <경로>\n이유: <판단 근거>\n\n이대로 진행할까요?",
  options: ["OK", "다른 위치로 변경"]
)
```

"OK"면 Step 3으로 진행. "다른 위치로 변경"이면 사용자 의견을 듣고 조정.

### 배치 위치 레퍼런스

| 조건 | 위치 | 비고 |
|------|------|------|
| Conclave 무관 | `~/claude-plugins/plugins/<name>/` | 마켓플레이스 (team-offlight), 글로벌 scope |
| Conclave 관련 + 앱 사용자 | `apps/desktop/resources/claude-code-kit/` | hookInstaller.ts 등록 필수, CONCLAVE_TERMINAL 가드 필수 |
| Conclave 관련 + 개발팀 | `.claude/skills/`, `.claude/hooks/`, `.claude/agents/` | 프로젝트 scope |

## Step 3: 생성/수정

### Skill

```
<위치>/skills/<name>/SKILL.md
```

필수 frontmatter:
```yaml
---
name: <name>
description: <한 줄 설명>
allowed-tools: <필요한 도구 목록>
user-invocable: true
---
```

### Hook

**claude-code-kit 훅:**
1. `apps/desktop/resources/claude-code-kit/hooks/<name>.sh` 생성
2. `hookInstaller.ts` HOOK_CONFIGS에 등록
3. CONCLAVE_TERMINAL 가드 추가

**프로젝트 훅:**
1. `.claude/hooks/<name>.sh` 생성
2. `.claude/settings.json` hooks에 등록

### Agent

```
<위치>/agents/<name>.md
```

필수 frontmatter:
```yaml
---
name: <name>
description: <한 줄 설명>
model: <sonnet|opus|haiku>
tools:
  - <도구 목록>
---
```

### 마켓플레이스 플러그인

1. `~/claude-plugins/plugins/<name>/` 디렉토리 생성
2. `.claude-plugin/plugin.json` 생성:
   ```json
   {
     "name": "<name>",
     "version": "0.0.1",
     "description": "<설명>",
     "author": { "name": "Team Offlight", "url": "https://github.com/namho-hong" },
     "repository": "https://github.com/namho-hong/team-offlight-claude-code-plugins",
     "license": "MIT"
   }
   ```
3. skills/, agents/, hooks/ 하위에 파일 배치
4. `~/claude-plugins/.claude-plugin/marketplace.json`의 plugins 배열에 추가

## Step 4: 검증

- 파일이 올바른 위치에 생성되었는지 확인
- frontmatter가 유효한지 확인
- 마켓플레이스인 경우 marketplace.json에 등록되었는지 확인
- claude-code-kit 훅인 경우 hookInstaller.ts에 등록되었는지 확인
- MCP 의존이 있는데 마켓플레이스에 넣으려 한 건 아닌지 재확인

## Step 4.5: 버전 범프 (마켓플레이스 플러그인만)

수정 시 `plugin.json`의 `version` patch를 올린다:

```bash
# 예: 0.0.3 → 0.0.4
cd ~/claude-plugins/plugins/<name>
python3 -c "
import json, pathlib
p = pathlib.Path('.claude-plugin/plugin.json')
d = json.loads(p.read_text())
parts = d['version'].split('.')
parts[2] = str(int(parts[2]) + 1)
d['version'] = '.'.join(parts)
p.write_text(json.dumps(d, indent=2, ensure_ascii=False) + '\n')
print(f'version: {d[\"version\"]}')
"
```

- 신규 생성 시 초기 버전: `0.0.1`
- 수정할 때마다 patch +1 (자동)
- major/minor 변경은 사용자가 수동으로 결정

## Step 5: 배포 & 활성화

**파일 생성 ≠ 배포 완료.** 배치 유형별로 활성화 단계가 다르다.

### 마켓플레이스 — 신규 설치

```bash
# 1. 커밋 + push
cd ~/claude-plugins
git add plugins/<name>/ .claude-plugin/marketplace.json
git commit -m "feat: <name> 플러그인 추가"
git push

# 2. 마켓플레이스 캐시 갱신
cd ~/.claude/plugins/marketplaces/team-offlight
git checkout -- . && git pull

# 3. 설치 (user scope = 글로벌)
claude plugin install <name>@team-offlight
```

### 마켓플레이스 — 기존 플러그인 수정

```bash
# 1. 커밋 + push (동일)
cd ~/claude-plugins && git add -A && git commit && git push

# 2. 캐시 갱신 (동일)
cd ~/.claude/plugins/marketplaces/team-offlight
git checkout -- . && git pull

# 3. 재설치 (캐시는 install 시점에만 갱신됨)
claude plugin install <name>@team-offlight
```

### 마켓플레이스 — 리네임

```bash
# Step 1.5에서 uninstall 완료 후:
# Step 5 신규 설치와 동일
```

### 공통: 현재 세션 반영

Step 5 완료 후 **반드시** 사용자에게 말한다:

> `/reload-plugins` 를 입력하시면 현재 세션에 바로 반영됩니다.

이건 빌트인 CLI 명령어라 도구로 호출 불가. 안내를 빠뜨리지 않는다.

### 프로젝트 .claude/

- 파일 생성 즉시 사용 가능 (다음 세션 또는 `/reload-plugins`)
- git commit은 팀 공유 목적
- `/reload-plugins` 안내 필수

### claude-code-kit

- 앱 빌드 후 hookInstaller 자동 설치
- 개발 중에는 수동으로 `~/.claude/`에 복사하여 테스트

## Step 6: 가드 복원

작업 완료 후 반드시 실행:

```bash
rm -f /tmp/manage-skill-active
```

## 금지 사항

- MCP 의존 있는 확장을 마켓플레이스에 넣지 않는다
- 글로벌 `~/.claude/skills/`에 직접 생성하지 않는다
- hookInstaller에 등록하지 않고 claude-code-kit 훅만 파일로 넣지 않는다
- installed_plugins.json이나 settings.json을 수동 편집하지 않는다 — `claude plugin install/uninstall` 사용
- 플러그인 훅을 hooks/ 디렉토리에만 넣고 plugin.json에 등록하지 않는다
