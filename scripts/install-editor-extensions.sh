#!/usr/bin/env bash
# Install editor extensions from declarative lists.
# Usage: ./scripts/install-editor-extensions.sh {cursor|vscode|all}

set -Eeuo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
EDITOR_ROOT="$DOTFILES/editor"

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

read_extensions() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    # trim
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue
    printf '%s\n' "$line"
  done < "$file"
}

install_with() {
  local cli="$1"
  shift
  local ext
  for ext in "$@"; do
    log "Installing ($cli): $ext"
    if "$cli" --install-extension "$ext" --force >/dev/null; then
      log "  OK: $ext"
    else
      log "  WARN: failed to install $ext (continuing)"
    fi
  done
}

install_cursor() {
  command -v cursor >/dev/null 2>&1 || die "cursor CLI not found in PATH"
  local -a exts=()
  local e
  while IFS= read -r e; do exts+=("$e"); done < <(
    { read_extensions "$EDITOR_ROOT/shared/extensions.shared.txt"
      read_extensions "$EDITOR_ROOT/cursor/extensions.txt"
    } | awk 'NF && !seen[$0]++'
  )
  if [[ ${#exts[@]} -eq 0 ]]; then
    log "No Cursor extensions declared."
    return 0
  fi
  install_with cursor "${exts[@]}"
}

install_vscode() {
  command -v code >/dev/null 2>&1 || die "code CLI not found in PATH"
  local -a exts=()
  local e
  while IFS= read -r e; do exts+=("$e"); done < <(
    { read_extensions "$EDITOR_ROOT/shared/extensions.shared.txt"
      read_extensions "$EDITOR_ROOT/vscode/extensions.txt"
    } | awk 'NF && !seen[$0]++'
  )
  if [[ ${#exts[@]} -eq 0 ]]; then
    log "No VS Code extensions declared."
    return 0
  fi
  install_with code "${exts[@]}"
}

usage() {
  cat <<'EOF'
Usage: ./scripts/install-editor-extensions.sh {cursor|vscode|all}
EOF
}

main() {
  local target="${1:-}"
  case "$target" in
    cursor) install_cursor ;;
    vscode) install_vscode ;;
    all)
      install_cursor
      install_vscode
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  log "Done."
}

main "$@"
