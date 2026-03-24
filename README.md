# Team Offlight Plugins for Claude Code

Claude Code plugins maintained by Team Offlight.

## Plugins

| Plugin | Commands | Description |
|--------|----------|-------------|
| `dual` | `/dual:search`, `/dual:plan`, `--agent dual:code` | Multi-model collaboration — Claude + Codex for fact verification, plan review, and code review |
| `spawn` | `/spawn` | Spawn a new Claude Code session in a Warp terminal tab |
| `ulp` | `/ulp` | Ultimate Loop Planning — 6-stage critique-based planning loop |

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
claude plugin install dual@team-offlight --scope project
claude plugin install spawn@team-offlight --scope project
claude plugin install ulp@team-offlight --scope project
```

## License

MIT
