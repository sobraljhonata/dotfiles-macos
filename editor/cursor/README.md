# Cursor-specific layer

Overrides and extensions that must **not** go into `editor/shared`.

- `settings.json` — merged on top of `shared/settings.base.json`
- `keybindings.json` — applied as-is to Cursor User
- `extensions.txt` — installed in addition to shared (Anysphere Remote IDs)

Source of truth for Cursor AI / Composer settings belongs here if you add any later — never in `shared/`.
