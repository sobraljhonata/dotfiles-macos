# Shared editor settings and assets

This directory holds **editor-agnostic** configuration used by both Cursor and VS Code.

| File / dir | Purpose |
| ---------- | ------- |
| `settings.base.json` | Settings merged into both editors |
| `extensions.shared.txt` | Extension IDs installed on both |
| `snippets/` | User snippets copied to both editors |

Do **not** put here:

- `cursor.*`, `composer.*`, chat / AI settings
- Copilot-only settings
- Remote extension IDs that differ between Cursor and VS Code

Apply with:

```bash
./scripts/apply-editor-settings.sh
./scripts/install-editor-extensions.sh all
```
