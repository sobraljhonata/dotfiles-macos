# Dotfiles

Ambiente de desenvolvimento macOS (**Apple Silicon**), reconstruível a partir deste repositório.

## Objetivo

```text
Mac novo → Homebrew → clonar dotfiles → ./install.sh → ./doctor.sh → pronto
```

## Ownership (fonte da verdade)

| Ferramenta | Owner |
| ---------- | ----- |
| Java 25 (Temurin) | SDKMAN |
| Maven 3.9.x | SDKMAN |
| Node.js LTS (24) | FNM |
| pnpm | Corepack |
| Angular CLI | npm global no Node do FNM |
| Flutter (global / fallback) | Homebrew cask |
| Flutter (por projeto) | FVM (Homebrew) |
| ADB / platform-tools | Android SDK |
| Docker CLI | Docker Desktop (cask) |
| VS Code | Homebrew cask |
| Cursor | aplicativo (CLI no PATH) |
| CLI / apps | Homebrew + `Brewfile` |

## Arquitetura

```text
Homebrew  → infraestrutura, CLIs, casks (Flutter, VS Code, Docker…)
SDKMAN    → Java + Maven
FNM       → Node (+ shell integration no .zshrc)
Corepack  → pnpm
FVM       → Flutter por projeto (.fvmrc)
editor/   → settings/extensões Cursor + VS Code (merge declarativo)
```

## Política Flutter

- **Global:** Homebrew (`flutter` / `dart` no PATH) — fallback.
- **Por projeto:** FVM (`.fvmrc` / `.fvm/`). Controle de versão fica no projeto.
- `install.sh` **não** executa `fvm use` nem altera projetos.
- **Não** use instalação legada `~/flutter` nem `dart.flutterSdkPath` apontando para ela.
- **Não** instale FVM via `dart pub global` — use Homebrew.

## Editores

Fonte da verdade: [`editor/`](editor/README.md).

```text
editor/shared/   → settings, extensions e snippets comuns
editor/cursor/   → overrides + extensões Cursor
editor/vscode/   → overrides + extensões VS Code
```

```bash
./scripts/apply-editor-settings.sh              # merge shared + specific → Application Support
./scripts/install-editor-extensions.sh all      # shared + específicas
```

Pastas top-level `cursor/` e `vscode/` foram removidas da arquitetura ativa; use apenas `editor/`.

## Git identity

A identidade **não** é versionada no repositório.

```bash
cp git/gitconfig.local.example ~/.gitconfig.local
# edite name + email reais
```

`git/.gitconfig` inclui `~/.gitconfig.local` via `[include]`.

## Comandos

```bash
./install.sh              # bootstrap idempotente
./install.sh --dry-run    # mostra ações sem mutar
./doctor.sh               # auditoria somente leitura (errors=0; Docker daemon pode ser WARNING)
./update.sh               # inventário local de extensões (não regenera Brewfile)

./scripts/apply-editor-settings.sh
./scripts/install-editor-extensions.sh {cursor|vscode|all}
```

## Bootstrap (`install.sh`)

1. Homebrew  
2. `brew bundle` (Brewfile)  
3. Links zsh/git  
4. SDKMAN → Java 25 → Maven  
5. FNM → Node LTS 24  
6. Corepack → pnpm  
7. Angular CLI (se ausente)  
8. Verifica Flutter/FVM  
9. Settings + extensões dos editores  
10. `doctor.sh`

Segunda execução deve detectar o que já existe e não quebrar o ambiente.

## Notas

- `update.sh` **não** executa `brew bundle dump --force`.
- Não versione `*.local`, `~/.gitconfig.local` nem `editor/**/extensions.installed.txt`.
- `editor/generated/` é artefato local (ignorado no Git).
