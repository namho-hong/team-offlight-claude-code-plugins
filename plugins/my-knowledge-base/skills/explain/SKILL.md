---
name: explain
description: |
  Explain a concept tailored to the user's existing knowledge.
  Reads the full Knowledge Base to understand what the user already knows,
  then uses that context to craft a personalized explanation of ANY topic.
  Trigger: "/my-knowledge-base explain", "explain using my KB",
  "다시 설명해줘 (KB 기반)", "내가 아는 거 기반으로 설명해줘"
allowed-tools:
  - Read
  - Glob
  - Grep
  - AskUserQuestion
  - Agent
  - WebFetch
  - WebSearch
---

# My Knowledge Base — Explain

Explain any concept — new or existing — by using the user's Knowledge Base as context.
The KB tells you what the user already knows, so you can build on that foundation.

## KB Location

`~/.claude/my-knowledge-base/`

## Core Principle

The KB is NOT a dictionary to look up topics.
The KB is a **profile of the user's mind** — use it to understand their starting point,
then explain anything (including brand new topics) from there.

## Steps

### 1. Identify What to Explain

- If argument is provided → explain that topic
- If no argument → explain the most recent concept discussed in this conversation

### 2. Read the FULL KB

From `~/.claude/my-knowledge-base/`:
1. Read `index.md` (category listing)
2. Read ALL category files — not just the one matching the topic
3. Build a picture of the user's overall knowledge landscape

You need the full picture because:
- A user asking about "Channels" might already know MCP, hooks, and plugins (✅)
  → Explain channels by contrasting with those known concepts
- Or they might be new to Claude Code entirely (mostly ❌)
  → Start from fundamentals

### 3. Analyze the User's Knowledge State

From the KB, identify:
- **✅ Know**: Concepts to use as anchors and analogies
- **❓ Uncertain**: Related areas to clarify along the way
- **❌ Don't know**: Foundations that may need brief explanation first

Also check timeline logs for patterns:
- Topics that regressed (✅→❓) → User tends to forget these — reinforce differently
- Topics that stayed ❌ for a long time → May need a different approach

### 4. Generate Tailored Explanation

Strategy:
1. **Anchor to known concepts**: "Since you understand hooks (✅), channels are similar in that..."
2. **Bridge from uncertain areas**: "You mentioned sub-agent lifecycle is uncertain — channels actually relate to this because..."
3. **Don't assume unknown foundations**: If the user doesn't know MCP (❌) and channels depend on MCP, briefly cover MCP first
4. **Skip what they know**: Don't re-explain plugin structure if it's ✅

### 5. For Claude Code topics specifically

If the topic is about Claude Code, delegate the factual research to the `claude-code-guide` agent.
Then apply the KB context to tailor the explanation.

Flow:
1. Read KB → understand user's knowledge state
2. Agent(claude-code-guide) → get accurate factual content
3. Combine: reshape the factual content using KB anchors

### 6. After Explaining

- Ask if it made sense
- Ask if there are follow-up questions

## Rules

- This skill is **read-only**. NEVER modify the KB. NEVER run assessments or quizzes.
- Assessments, quizzes, and KB writes belong EXCLUSIVELY to the update skill. Do NOT do them here.
- If the user asks for assessment while in this skill, tell them to run `/my-knowledge-base:update` instead.
- The topic being explained does NOT need to exist in the KB. The KB provides context, not content.
- Do NOT parrot back what the user already knows. Use it as scaffolding, not as output.
- For Claude Code questions, always use claude-code-guide agent for factual accuracy.
