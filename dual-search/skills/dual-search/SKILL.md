---
name: dual-search
description: |
  Cross-model fact verification using Claude + Codex in parallel with convergence loop.
  Trigger: "/dual-search", "dual search", "교차 검증", "cross verify",
  "팩트체크", "fact check", "이거 맞아?", "진짜야?",
  "두 모델로 확인해줘", "codex랑 비교해줘"
allowed-tools:
  - Agent
  - Bash
  - WebSearch
  - WebFetch
  - Read
  - Grep
  - Glob
---

# /dual-search — Cross-Model Fact Verification

Runs the same factual question through **Claude (WebSearch)** and **Codex CLI** in parallel,
then compares results. If they disagree, each model researches the disagreement point
and the loop repeats until convergence or max rounds.

## When to Use

- Factual claims that could be hallucinated ("X is open source", "Y supports Z")
- Licensing, version, compatibility questions
- Any statement where being wrong has real consequences

## Input

The user provides a factual question or claim to verify.

```
/dual-search "Claude Code는 오픈소스인가?"
/dual-search "ripgrep은 Go로 만들어졌나?"
```

If no argument is provided, use AskUserQuestion to ask what to verify.

## Execution Flow

### Round 1: Parallel Search

Launch both searches **simultaneously** in a single message with two tool calls:

**Claude Search** — spawn an Agent:
```
Agent(subagent_type="general-purpose", prompt="""
Search the web for: {QUESTION}
Find at least 3 sources. For each source, note:
- URL
- What it says about the question
- Whether it confirms or denies

Return a structured answer:
ANSWER: [your conclusion]
CONFIDENCE: [HIGH/MEDIUM/LOW]
SOURCES:
- [url1]: [what it says]
- [url2]: [what it says]
- [url3]: [what it says]
""")
```

**Codex Search** — run via Bash:
```bash
codex exec "Search the web and answer this question with sources: {QUESTION}. Return your answer as: ANSWER: [conclusion], CONFIDENCE: [HIGH/MEDIUM/LOW], SOURCES: [list urls and what each says]" 2>&1
```

### Round 2+: Convergence Loop (if disagreement)

Compare the two results. If they **disagree**:

1. Identify the specific point of disagreement
2. Formulate a **narrower, more specific** follow-up question targeting the disagreement
3. Run both searches again with the narrowed question
4. Compare again

**Example:**
```
Round 1:
  Claude: "Claude Code is open source (MIT)"
  Codex:  "Claude Code is proprietary (All Rights Reserved)"
  → DISAGREE on: license type

Round 2 (narrowed question):
  "What is the exact text of LICENSE.md in the anthropics/claude-code GitHub repository?"
  Claude: "© Anthropic PBC. All rights reserved."
  Codex:  "All Rights Reserved, not OSI-approved"
  → AGREE: proprietary
```

### Circuit Breaker

- **Max 3 rounds**. If still disagreeing after 3 rounds, report both positions and let user decide.
- Each round narrows the question further — never repeat the same question.

## Output Format

```markdown
## Dual Search Result

**Question**: {original question}
**Verdict**: ✅ AGREE / ⚠️ DISAGREE (after {N} rounds)

### Claude (WebSearch)
**Answer**: ...
**Confidence**: HIGH/MEDIUM/LOW
**Sources**:
- [url]: summary
- [url]: summary

### Codex (GPT)
**Answer**: ...
**Confidence**: HIGH/MEDIUM/LOW
**Sources**:
- [url]: summary
- [url]: summary

### Convergence Analysis
- **Agreed on**: ...
- **Disagreed on**: ... (if any)
- **Resolution**: ... (how disagreement was resolved, or "unresolved — user judgment needed")

### Rounds
- Round 1: {question} → {agree/disagree on what}
- Round 2: {narrowed question} → {agree/disagree on what}
...
```

## Rules

- NEVER skip the Codex search. Both must run.
- NEVER fabricate Codex results. If Codex call fails, report the failure.
- Each round's question must be MORE SPECIFIC than the previous.
- Always show sources from both sides.
- Present disagreements honestly — don't force agreement.
- Korean output for explanations, English for technical terms.
