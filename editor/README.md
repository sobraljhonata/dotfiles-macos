# Editor configuration

Declarative Cursor + VS Code setup. **Do not** symlink Application Support directories between editors.

```text
editor/
├── shared/     # editor-agnostic settings, extensions, snippets
├── cursor/     # Cursor-only overrides + extensions
└── vscode/     # VS Code-only overrides + extensions
```

Merged settings are written as real files under:

```text
~/Library/Application Support/Cursor/User/settings.json
~/Library/Application Support/Code/User/settings.json
```

## Apply settings

```bash
./scripts/apply-editor-settings.sh
```

## Install extensions

```bash
./scripts/install-editor-extensions.sh cursor
./scripts/install-editor-extensions.sh vscode
./scripts/install-editor-extensions.sh all
```

## Where to put changes

| Change | Location |
| ------ | -------- |
| Setting useful in both editors | `shared/settings.base.json` |
| Cursor-only / AI settings | `editor/cursor/settings.json` |
| VS Code-only settings | `editor/vscode/settings.json` |
| Extension for both | `shared/extensions.shared.txt` |
| Cursor-only extension | `editor/cursor/extensions.txt` |
| VS Code-only extension | `editor/vscode/extensions.txt` |
| Shared snippet | `shared/snippets/<lang>.json` |

After editing settings JSON, re-run `apply-editor-settings.sh`.

## Flutter / Dart

Do **not** set `dart.flutterSdkPath` to `~/flutter`.

- Global Flutter: Homebrew (`flutter` / `dart` on PATH)
- Per project: FVM (`.fvmrc` / `.fvm/`) — Dart/Flutter extensions detect project SDK

## Legacy folders

Pastas top-level `cursor/` e `vscode/` foram removidas; use apenas `editor/`.
