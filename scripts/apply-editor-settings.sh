#!/usr/bin/env bash
# Merge shared + editor-specific settings and apply to Cursor / VS Code User dirs.
# Idempotent. Uses python3 (macOS). Does not symlink between editors.

set -Eeuo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
EDITOR_ROOT="$DOTFILES/editor"
GEN_ROOT="$EDITOR_ROOT/generated"
CURSOR_USER="$HOME/Library/Application Support/Cursor/User"
CODE_USER="$HOME/Library/Application Support/Code/User"
STAMP="$(date +%Y%m%d%H%M%S)"

log() { printf '%s\n' "$*"; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

require_file() {
  local f="$1"
  [[ -f "$f" ]] || die "missing file: $f"
}

validate_json() {
  local f="$1"
  python3 -m json.tool "$f" >/dev/null || die "invalid JSON: $f"
}

backup_target() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    local dest="${target}.backup.${STAMP}"
    # Copy content even if symlink
    if [[ -L "$target" ]]; then
      cp -p "$target" "$dest" 2>/dev/null || cp -pH "$target" "$dest"
    else
      cp -p "$target" "$dest"
    fi
    log "Backup: $dest"
  fi
}

write_file() {
  local source="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"
  backup_target "$target"
  # Replace symlink with real file
  rm -f "$target"
  cp "$source" "$target"
  log "Wrote: $target"
}

merge_settings() {
  local base="$1"
  local specific="$2"
  local out="$3"

  python3 - "$base" "$specific" "$out" <<'PY'
import json
import sys
from pathlib import Path

def deep_merge(a, b):
    if isinstance(a, dict) and isinstance(b, dict):
        out = dict(a)
        for k, v in b.items():
            if k in out:
                out[k] = deep_merge(out[k], v)
            else:
                out[k] = v
        return out
    return b

base_path, specific_path, out_path = sys.argv[1], sys.argv[2], sys.argv[3]
base = json.loads(Path(base_path).read_text(encoding="utf-8"))
specific = json.loads(Path(specific_path).read_text(encoding="utf-8"))
if not isinstance(base, dict) or not isinstance(specific, dict):
    raise SystemExit("settings files must be JSON objects")
merged = deep_merge(base, specific)
Path(out_path).write_text(
    json.dumps(merged, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
PY
}

sync_snippets() {
  local dest_dir="$1"
  local src_dir="$EDITOR_ROOT/shared/snippets"
  mkdir -p "$dest_dir"
  # Only copy non-empty *.json snippet files
  local found=0
  shopt -s nullglob
  for f in "$src_dir"/*.json; do
    if [[ -s "$f" ]]; then
      cp "$f" "$dest_dir/"
      found=1
      log "Snippet: $(basename "$f") -> $dest_dir/"
    fi
  done
  shopt -u nullglob
  if [[ "$found" -eq 0 ]]; then
    log "No shared snippets to copy (empty or absent)."
  fi
}

main() {
  command -v python3 >/dev/null 2>&1 || die "python3 is required"

  local base="$EDITOR_ROOT/shared/settings.base.json"
  local cursor_specific="$EDITOR_ROOT/cursor/settings.json"
  local vscode_specific="$EDITOR_ROOT/vscode/settings.json"
  local cursor_keys="$EDITOR_ROOT/cursor/keybindings.json"
  local vscode_keys="$EDITOR_ROOT/vscode/keybindings.json"

  require_file "$base"
  require_file "$cursor_specific"
  require_file "$vscode_specific"
  require_file "$cursor_keys"
  require_file "$vscode_keys"

  validate_json "$base"
  validate_json "$cursor_specific"
  validate_json "$vscode_specific"
  validate_json "$cursor_keys"
  validate_json "$vscode_keys"

  mkdir -p "$GEN_ROOT" "$CURSOR_USER" "$CODE_USER"

  local gen_cursor="$GEN_ROOT/cursor.settings.json"
  local gen_vscode="$GEN_ROOT/vscode.settings.json"

  merge_settings "$base" "$cursor_specific" "$gen_cursor"
  merge_settings "$base" "$vscode_specific" "$gen_vscode"
  validate_json "$gen_cursor"
  validate_json "$gen_vscode"

  write_file "$gen_cursor" "$CURSOR_USER/settings.json"
  write_file "$gen_vscode" "$CODE_USER/settings.json"
  write_file "$cursor_keys" "$CURSOR_USER/keybindings.json"
  write_file "$vscode_keys" "$CODE_USER/keybindings.json"

  sync_snippets "$CURSOR_USER/snippets"
  sync_snippets "$CODE_USER/snippets"

  # Ensure no legacy ~/flutter SDK path in applied settings
  if grep -F "${HOME}/flutter" "$CURSOR_USER/settings.json" "$CODE_USER/settings.json" 2>/dev/null; then
    die "merged settings still reference legacy ~/flutter"
  fi

  log "Done. Cursor + VS Code settings applied."
}

main "$@"
