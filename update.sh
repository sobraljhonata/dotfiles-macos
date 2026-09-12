#!/usr/bin/env bash

set -Eeuo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
EDITOR_ROOT="$DOTFILES/editor"

echo "Atualizando listas de extensões (não altera Brewfile automaticamente)..."

if command -v cursor >/dev/null 2>&1; then
  cursor --list-extensions | sort > "$EDITOR_ROOT/cursor/extensions.installed.txt"
  echo "Cursor instaladas -> editor/cursor/extensions.installed.txt"
  echo "Revise e promova IDs para shared/ ou cursor/extensions.txt manualmente."
else
  echo "cursor CLI ausente; pulando."
fi

if command -v code >/dev/null 2>&1; then
  code --list-extensions | sort > "$EDITOR_ROOT/vscode/extensions.installed.txt"
  echo "VS Code instaladas -> editor/vscode/extensions.installed.txt"
  echo "Revise e promova IDs para shared/ ou vscode/extensions.txt manualmente."
else
  echo "code CLI ausente; pulando."
fi

cd "$DOTFILES"
git status --short

echo
echo "Brewfile NÃO foi regenerado (evita dump --force)."
echo "Revise as alterações antes de um commit futuro."
