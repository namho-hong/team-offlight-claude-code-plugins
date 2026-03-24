# Team Offlight Plugins for Claude Code

Claude Code plugins maintained by Team Offlight.

## Plugins

| Plugin | Description |
|--------|-------------|
| `dual-search` | Cross-model fact verification (Claude + Codex) with convergence loop |
| `dual-plan` | Plan review duel between Claude and Codex, iterates until consensus |
| `dual-code` | Code review duel — Codex reviews, sonnet fixes, opus judges |
| `spawn` | Spawn a new Claude Code session in a Warp terminal tab |
| `ulp` | Ultimate Loop Planning — 6-stage critique-based planning loop |

## Installation

Add marketplace to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "team-offlight": {
      "source": {
        "source": "github",
        "repo": "offlightinc/claude-plugins"
      }
    }
  }
}
```

Then install individual plugins:

```bash
claude plugin install dual-search@team-offlight --scope project
claude plugin install dual-plan@team-offlight --scope project
claude plugin install dual-code@team-offlight --scope project
claude plugin install spawn@team-offlight --scope project
claude plugin install ulp@team-offlight --scope project
```

## License

MIT
