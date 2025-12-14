# Show Port Allocation

Display port allocation table for all worktree colors.

## Usage

No arguments needed. Simply run:

```bash
./.claude/commands/worktree/scripts/show_ports.sh
```

## Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Worktree Port Allocation
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Color      Backend Port    Frontend Port   Database Name
────────────────────────────────────────────────────────────
main       6789            3000            ${PROJECT_NAME}
blue       6799            3010            ${PROJECT_NAME}_blue
red        6809            3020            ${PROJECT_NAME}_red
white      6819            3030            ${PROJECT_NAME}_white

Port calculation:
  Backend:  6789 + (color_offset * 10)
  Frontend: 3000 + (color_offset * 10)

Color offsets:
  main:  0 (no offset)
  blue:  0
  red:   1
  white: 2
```

## When To Use

- Planning which worktree to create
- Troubleshooting port conflicts
- Connecting external tools to worktree services
- Documentation reference

## Note

Port allocation is deterministic and cannot be changed without modifying scripts.
