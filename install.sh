#!/usr/bin/env bash
# install.sh — idempotent bootstrap for macOS Apple Silicon dotfiles.
# Usage:
#   ./install.sh
#   ./install.sh --dry-run

set -Eeuo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
DRY_RUN=0
JAVA_CANDIDATE="${JAVA_CANDIDATE:-25-tem}"
MAVEN_CANDIDATE="${MAVEN_CANDIDATE:-3.9.16}"
NODE_MAJOR_POLICY="${NODE_MAJOR_POLICY:-24}"

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -h|--help)
      cat <<'EOF'
Usage: ./install.sh [--dry-run]

Idempotent bootstrap:
  Homebrew + Brewfile, shell links, SDKMAN/Java/Maven,
  FNM/Node LTS, Corepack/pnpm, Angular CLI (if missing),
  editor settings + extensions, doctor.
EOF
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 1
      ;;
  esac
done

log() { printf '%s\n' "$*"; }
section() { printf '\n==> %s\n' "$*"; }

run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

backup_file() {
  local file="$1"
  if [[ -e "$file" && ! -L "$file" ]]; then
    run mv "$file" "${file}.backup.$(date +%Y%m%d%H%M%S)"
  fi
}

create_link() {
  local source="$1"
  local destination="$2"
  mkdir -p "$(dirname "$destination")"
  backup_file "$destination"
  run ln -sfn "$source" "$destination"
  log "Link: $destination -> $source"
}

ensure_brew() {
  section "1. Homebrew"
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew already installed: $(brew --version | head -1)"
    return 0
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    log "Loaded Homebrew from /opt/homebrew"
    return 0
  fi
  log "Homebrew not found. Install from https://brew.sh then re-run."
  exit 1
}

bundle_brewfile() {
  section "2. Brewfile"
  if [[ ! -f "$DOTFILES/Brewfile" ]]; then
    log "Brewfile missing"; exit 1
  fi
  run brew bundle --file="$DOTFILES/Brewfile"
}

link_shell_git() {
  section "3. Shell + Git links"
create_link "$DOTFILES/zsh/.zshrc" "$HOME/.zshrc"
create_link "$DOTFILES/zsh/.zprofile" "$HOME/.zprofile"
create_link "$DOTFILES/git/.gitconfig" "$HOME/.gitconfig"

if [[ ! -f "$HOME/.gitconfig.local" ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] would create ~/.gitconfig.local from example if missing"
  else
    cp "$DOTFILES/git/gitconfig.local.example" "$HOME/.gitconfig.local"
    log "Created ~/.gitconfig.local — edit name/email before committing."
  fi
fi
}

load_sdkman() {
  export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
  [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] || return 1
  set +u
  # shellcheck disable=SC1091
  source "$SDKMAN_DIR/bin/sdkman-init.sh"
  set -u
}

ensure_sdkman() {
  section "4. SDKMAN"
  export SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
  if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    log "SDKMAN already installed"
  else
    log "Installing SDKMAN..."
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log "[dry-run] curl ... | bash (SDKMAN)"
    else
      curl -s "https://get.sdkman.io" | bash
    fi
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi
  load_sdkman
}

ensure_java() {
  section "5. Java (SDKMAN)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] ensure java $JAVA_CANDIDATE"
    return 0
  fi
  load_sdkman
  if sdk current java 2>/dev/null | grep -Eq '25|'"$JAVA_CANDIDATE"; then
    log "Java already on policy (25 / $JAVA_CANDIDATE)"
  elif [[ -d "$SDKMAN_DIR/candidates/java/$JAVA_CANDIDATE" ]]; then
    log "Setting default Java to $JAVA_CANDIDATE"
    sdk default java "$JAVA_CANDIDATE" || true
  else
    log "Installing Java $JAVA_CANDIDATE"
    sdk install java "$JAVA_CANDIDATE" <<<"Y" || sdk install java "$JAVA_CANDIDATE"
    sdk default java "$JAVA_CANDIDATE" || true
  fi
  java -version
}

ensure_maven() {
  section "6. Maven (SDKMAN)"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] ensure maven $MAVEN_CANDIDATE"
    return 0
  fi
  load_sdkman
  if sdk current maven 2>/dev/null | grep -q "$MAVEN_CANDIDATE"; then
    log "Maven already $MAVEN_CANDIDATE"
  elif [[ -d "$SDKMAN_DIR/candidates/maven/$MAVEN_CANDIDATE" ]]; then
    sdk default maven "$MAVEN_CANDIDATE" || true
  else
    log "Installing Maven $MAVEN_CANDIDATE"
    sdk install maven "$MAVEN_CANDIDATE" <<<"Y" || sdk install maven "$MAVEN_CANDIDATE"
    sdk default maven "$MAVEN_CANDIDATE" || true
  fi
  mvn -version | head -3
}

ensure_fnm_node() {
  section "7. FNM + Node"
  if ! command -v fnm >/dev/null 2>&1; then
    log "fnm missing after Brewfile — aborting Node bootstrap"
    exit 1
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] fnm install --lts && fnm default <lts>"
    return 0
  fi
  eval "$(fnm env --shell bash)"
  local current
  current="$(node --version 2>/dev/null || true)"
  if [[ "$current" == v${NODE_MAJOR_POLICY}.* ]]; then
    log "Node already on v${NODE_MAJOR_POLICY}.x ($current) — preserving"
  else
    log "Installing Node LTS via FNM"
    fnm install --lts
    local lts
    lts="$(fnm list | awk '/lts-latest/{print $2; exit}' | tr -d 'v' || true)"
    if [[ -z "$lts" ]]; then
      fnm install 24
      fnm default 24
    else
      fnm default --lts-latest 2>/dev/null || fnm default "$lts" || true
    fi
  fi
  eval "$(fnm env --shell bash)"
  node --version
  npm --version
}

ensure_pnpm() {
  section "8. Corepack / pnpm"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] corepack enable && corepack prepare pnpm@latest --activate"
    return 0
  fi
  if command -v corepack >/dev/null 2>&1; then
    corepack enable || true
    corepack prepare pnpm@latest --activate || true
  else
    log "corepack missing; skipping pnpm bootstrap"
    return 0
  fi
  pnpm --version
}

ensure_angular() {
  section "9. Angular CLI"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] npm install -g @angular/cli (if missing)"
    return 0
  fi
  eval "$(fnm env --shell bash)" 2>/dev/null || true
  if command -v ng >/dev/null 2>&1; then
    log "Angular CLI already present: $(ng version 2>/dev/null | awk -F': ' '/Angular CLI/{print $2; exit}')"
  else
    log "Installing @angular/cli globally via npm (FNM Node)"
    npm install -g @angular/cli
  fi
}

ensure_flutter_fvm() {
  section "10. Flutter / FVM"
  if command -v flutter >/dev/null 2>&1; then
    log "Flutter: $(flutter --version 2>/dev/null | head -1)"
  else
    log "Flutter missing — ensure Brewfile cask flutter installed"
  fi
  if command -v fvm >/dev/null 2>&1; then
    log "FVM: $(fvm --version 2>/dev/null | head -1)"
  else
    log "FVM missing — ensure Brewfile formula fvm installed"
  fi
  log "Per-project Flutter versions are managed with FVM (not changed by install.sh)."
}

apply_editors() {
  section "11–13. Editors (settings + extensions)"
  run "$DOTFILES/scripts/apply-editor-settings.sh"
  if command -v cursor >/dev/null 2>&1; then
    run "$DOTFILES/scripts/install-editor-extensions.sh" cursor || true
  else
    log "cursor CLI missing — skip Cursor extensions"
  fi
  if command -v code >/dev/null 2>&1; then
    run "$DOTFILES/scripts/install-editor-extensions.sh" vscode || true
  else
    log "code CLI missing — skip VS Code extensions"
  fi
}

run_doctor() {
  section "14. Doctor"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] $DOTFILES/doctor.sh"
    return 0
  fi
  "$DOTFILES/doctor.sh" || {
    log "doctor reported errors — review output above"
    return 1
  }
}

main() {
  log "DOTFILES=$DOTFILES"
  [[ "$DRY_RUN" -eq 1 ]] && log "Mode: DRY-RUN (no mutations)"

  ensure_brew
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  bundle_brewfile
  link_shell_git
  ensure_sdkman
  ensure_java
  ensure_maven
  ensure_fnm_node
  ensure_pnpm
  ensure_angular
  ensure_flutter_fvm
  apply_editors
  run_doctor

  log
  log "Configuração concluída."
  log "Reinicie o terminal ou: source ~/.zshrc"
}

main "$@"
