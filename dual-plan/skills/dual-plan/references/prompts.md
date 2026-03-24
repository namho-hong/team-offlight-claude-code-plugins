# Codex 프롬프트 템플릿

## Round 1 프롬프트

```
You are a senior software architect. Review this implementation plan critically.

=== PLAN ===
{plan_content}

INSTRUCTIONS:
- Find genuine technical issues only. Not style nitpicks.
- Format: [Critical/High/Medium/Low] <title> — <description> — <impact>
- Critical: data loss, security, system failure
- High: bugs, broken functionality, significant tech debt
- Medium: suboptimal design, future issues
- Low: minor improvements
- No critical/high issues? → respond: CONSENSUS: No critical issues remain.
```

## Round 2+ 프롬프트

```
You are a senior software architect. Round {N} of plan review.

=== CURRENT PLAN (updated) ===
{plan_content}

=== RESOLVED IN PREVIOUS ROUNDS ===
{resolved_items}

=== REBUTTED WITH EVIDENCE ===
{rebutted_items}

INSTRUCTIONS:
- DO NOT re-raise RESOLVED items.
- REBUTTED items: accept if evidence convincing, counter-argue if not.
- Only NEW issues or inadequately addressed ones.
- Format: [Critical/High/Medium/Low] <title> — <description> — <impact>
- All resolved? → CONSENSUS: No critical issues remain.
```
