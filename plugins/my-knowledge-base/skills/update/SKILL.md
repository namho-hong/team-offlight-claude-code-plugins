---
name: update
description: |
  Update My Knowledge Base after learning something new.
  Trigger: "/my-knowledge-base update", "update knowledge base",
  "save what I learned", "지식 업데이트", "배운 거 저장"
allowed-tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
  - AskUserQuestion
---

# My Knowledge Base — Update

Record what you learned in this conversation into your Knowledge Base.

## KB Location

`~/.claude/my-knowledge-base/`

## File Structure

Knowledge is organized by category:
- `~/.claude/my-knowledge-base/index.md` — Category listing
- `~/.claude/my-knowledge-base/<category>.md` — Per-category knowledge file

## Steps

### 1. Analyze Conversation Context

Extract what the user learned in this conversation:
- Newly acquired concepts
- Things they thought they knew but turned out to be wrong
- Things that went from uncertain to certain
- Things that went from certain back to uncertain (forgotten or invalidated)

### 2. Determine Category

Decide which category the extracted knowledge belongs to.
- If existing category matches → append to that file
- If no match → create new category file + update index.md
- If ambiguous → ask the user

### 3. Read Existing KB

From `~/.claude/my-knowledge-base/`:
1. Read `index.md` (category listing)
2. Read the relevant category file
3. Check if the same topic already exists

### 4. Self-Assessment per Topic

**NON-NEGOTIABLE: You MUST call the AskUserQuestion tool for this step.**
Do NOT print options as plain text. Do NOT ask the user to type a number.
The AskUserQuestion tool provides interactive selection UI — use it.

For each extracted topic, call AskUserQuestion exactly like this:

```json
{
  "questions": [{
    "question": "How well do you understand <Topic Name>?",
    "header": "Level",
    "multiSelect": false,
    "options": [
      { "label": "Know it well", "description": "Can explain it to someone else confidently" },
      { "label": "Somewhat uncertain", "description": "Got the gist but not confident on details" },
      { "label": "Don't really get it", "description": "Need to revisit this topic" },
      { "label": "Assess me", "description": "Run a quiz to verify my understanding" }
    ]
  }]
}
```

Mapping:
- **"Know it well" → ✅ Know**: Record as self-assessed
- **"Somewhat uncertain" → ❓ Uncertain**: Record as self-assessed
- **"Don't really get it" → ❌ Don't know**: Record as self-assessed
- **"Assess me" → Run Assessment**: See Step 5
- **"Other" (auto-provided)**: User can type a custom note — interpret and map accordingly

When there are multiple topics, ask one question per topic sequentially.
Do NOT try to batch all topics into a single text prompt.

### 5. Assessment (only when requested)

Triggered ONLY when:
- User picks option 4 ("Assess me") for a topic
- User explicitly asks for assessment at any point

Assessment flow:
1. Generate 4 questions about the topic
2. **NON-NEGOTIABLE: Present ALL 4 questions in a SINGLE AskUserQuestion call.**
   Do NOT print quiz questions as plain text. Do NOT ask the user to type answers.
   Do NOT call AskUserQuestion multiple times — put all 4 questions in one call.

```json
{
  "questions": [
    {
      "question": "Q1: Webhook과 Polling의 핵심 차이는?",
      "header": "Q1",
      "multiSelect": false,
      "options": [
        { "label": "Webhook이 Polling보다 느리다", "description": "" },
        { "label": "Webhook은 이벤트 발생 시 push, Polling은 반복 조회", "description": "" },
        { "label": "잘 모르겠음", "description": "" }
      ]
    },
    {
      "question": "Q2: Webhook에서 받는 쪽이 해야 하는 일은?",
      "header": "Q2",
      "multiSelect": false,
      "options": [
        { "label": "상대 서버에 반복 요청 보내기", "description": "" },
        { "label": "HTTP POST를 받을 수 있는 URL을 열어놓기", "description": "" },
        { "label": "잘 모르겠음", "description": "" }
      ]
    }
  ]
}
```

**CRITICAL — AskUserQuestion formatting rules (DO NOT VIOLATE):**
- All 4 questions in ONE call (AskUserQuestion supports up to 4 questions)
- `label` = the full answer text that the user sees and selects. NEVER use "A", "B", "C", "D" as labels.
- `description` = always empty string `""`. NEVER put answer content in description.
- Last option of each question = "don't know" in the user's language (e.g., "잘 모르겠음" for Korean).
- "Don't know" is always counted as incorrect.
- Use the user's conversation language for both question and label text.
- Each question should have 3 options: 1 correct + 1 wrong + "don't know"

3. Evaluate answers
4. Map score to level:
   - 0-1 correct → ❌ Don't know
   - 2-3 correct → ❓ Uncertain
   - 4 correct → ✅ Know
5. **Synthesize a knowledge analysis** (NOT raw O/X listing):
   - What the user demonstrably understands (concepts behind correct answers)
   - Where the gaps are (WHY they got it wrong, what concept is missing)
   - This analysis is what gets recorded — not the raw quiz results
6. Record with score + analysis: e.g., `❓ Uncertain (2/4) — Assessed. <analysis>`

### 6. Update KB

#### Format — self-assessed (no score)

```markdown
### <Topic Name>
- **Level**: ❓ Uncertain
- 2026-03-22: ❓ Uncertain — Self-assessed. Understood the basics but not confident on edge cases
```

#### Format — after assessment (with synthesized analysis)

DO NOT list raw O/X results. Synthesize what the user knows and where the gaps are.

```markdown
### <Topic Name>
- **Level**: ❓ Uncertain (2/4)
- 2026-03-22: ❓ Uncertain (2/4) — Assessed. Understands the push/pull cycle and conflict resolution flow. Gaps: doesn't yet grasp the upstream tracking concept (why -u is needed on first push) and the relationship between commit and push (that push only sends committed snapshots, not working directory changes).
```

❌ BAD (raw O/X listing — NEVER do this):
```markdown
- 2026-03-22: ❓ Uncertain (2/4) — Assessed: commit 단위 전송(✅), 충돌 시 reject(✅), upstream 설정(❌), commit 없이 push(❌)
```

✅ GOOD (synthesized analysis):
```markdown
- 2026-03-22: ❓ Uncertain (2/4) — Assessed. Understands that git transfers commits (not files) and knows the conflict→pull→push flow. Gaps: the concept of upstream branch tracking and the prerequisite of committing before pushing.
```

#### Existing topic — append timeline entry

NEVER delete existing entries. Append only:

```markdown
### <Topic Name>
- **Level**: ✅ Know  ← update to latest level
- [initial]: ❌ Don't know — Had never encountered this
- 2026-03-20: ❓ Uncertain — Self-assessed after first reading
- 2026-03-22: ✅ Know (4/4) — Assessed. Solid grasp of all core concepts including upstream tracking and commit-push relationship.
```

Levels can change in any direction:
- ✅ → ❓ (thought I knew, but was wrong or forgot)
- ❓ → ✅ (confirmed understanding)
- ✅ → ❌ (completely wrong assumption exposed)

If two level changes happen on the same date, add HH:MM to disambiguate.

### 7. Update index.md

```markdown
# My Knowledge Base

| Category | File | Entries | Last Updated |
|----------|------|---------|-------------|
| Claude Code | claude-code.md | 12 | 2026-03-22 |
```

### 8. Report

Summarize to the user:
- New topics added
- Topics with level changes (before → after)
- Assessment results (if any)
- Total entry count

## Rules

- Existing timeline entries are **NEVER deleted** (append-only)
- Only **Level** (current) is updated to reflect latest state
- Always use absolute dates (YYYY-MM-DD), add HH:MM only when same-day conflict
- Memos should include "what was learned and in what context"
- Do NOT add content the user didn't explicitly discuss or confirm
- Score (N/5) is ONLY recorded when assessment was performed. Self-assessed entries have no score.
- Assessment is NEVER forced. Only runs on user's explicit choice (option 4) or request.
