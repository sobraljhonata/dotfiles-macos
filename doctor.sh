#!/usr/bin/env bash
# doctor.sh — read-only environment health check against dotfiles policy.
# Exit 0: OK or acceptable warnings only
# Exit 1: one or more ERROR conditions

set -Eeuo pipefail

DOTFILES="${DOTFILES:-$HOME/dotfiles}"
ERRORS=0
WARNINGS=0

ok() { printf '[OK] %s\n' "$*"; }
warn() { printf '[WARNING] %s\n' "$*"; WARNINGS=$((WARNINGS + 1)); }
err() { printf '[ERROR] %s\n' "$*"; ERRORS=$((ERRORS + 1)); }

have() { command -v "$1" >/dev/null 2>&1; }

# Prefer login-like toolchain visibility
export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null)" || true
fi
# Android SDK platform-tools (policy owner for adb)
android_sdk_default="$HOME/Library/Android/sdk"
if [[ -d "$android_sdk_default/platform-tools" ]]; then
  export PATH="$android_sdk_default/platform-tools:$android_sdk_default/emulator:$PATH"
fi
if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
  # SDKMAN assumes zsh vars may exist; neutralize nounset for the source.
  set +u
  # shellcheck disable=SC1091
  source "$HOME/.sdkman/bin/sdkman-init.sh"
  set -u
fi
if have fnm; then
  eval "$(fnm env --shell bash 2>/dev/null)" || true
fi

printf '=== dotfiles doctor ===\n'
printf 'DOTFILES=%s\n\n' "$DOTFILES"

# --- System ---
arch="$(uname -m)"
if [[ "$arch" == "arm64" ]]; then
  ok "macOS arch arm64 ($(sw_vers -productVersion 2>/dev/null || true))"
else
  err "Expected Apple Silicon arm64, got: $arch"
fi

if have brew; then
  ok "Homebrew $(brew --version 2>/dev/null | head -1)"
else
  err "Homebrew missing"
fi

if [[ "${SHELL:-}" == *zsh* ]] || [[ -n "${ZSH_VERSION:-}" ]] || have zsh; then
  ok "zsh available"
else
  warn "zsh not detected as current shell"
fi

# --- PATH policy ---
if echo "${PATH:-}" | tr ':' '\n' | grep -Fqx "$HOME/flutter/bin" || echo "${PATH:-}" | tr ':' '\n' | grep -Fq "$HOME/flutter/bin"; then
  err "PATH contains legacy ~/flutter/bin"
else
  ok "No legacy Flutter path in PATH"
fi

# --- SDKMAN / Java / Maven ---
if [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
  ok "SDKMAN present"
else
  err "SDKMAN missing (~/.sdkman)"
fi

if have java; then
  jv="$(java -version 2>&1 | head -1 || true)"
  if echo "$jv" | grep -Eq '"?25([."]|$)'; then
    ok "Java 25 ($jv)"
  else
    err "Java is not 25: $jv"
  fi
else
  err "java not found"
fi

if [[ -n "${JAVA_HOME:-}" ]] && [[ "$JAVA_HOME" == *sdkman* ]]; then
  ok "JAVA_HOME via SDKMAN ($JAVA_HOME)"
elif [[ -n "${JAVA_HOME:-}" ]]; then
  warn "JAVA_HOME set but not under SDKMAN: $JAVA_HOME"
else
  # macOS /usr/bin/java may still work via java_home
  warn "JAVA_HOME unset (java may still work via stubs)"
fi

if have mvn; then
  mv="$(mvn -version 2>/dev/null | head -1 || true)"
  mhome="$(mvn -version 2>/dev/null | awk -F': ' '/Maven home/{print $2; exit}')"
  if [[ "$mhome" == *sdkman* ]]; then
    ok "Maven via SDKMAN ($mv)"
  else
    warn "Maven found but home not SDKMAN: $mhome"
  fi
  if echo "$mv" | grep -q '3.9.16'; then
    ok "Maven 3.9.16"
  else
    warn "Maven version differs from policy 3.9.16: $mv"
  fi
else
  err "mvn not found"
fi

# --- FNM / Node / pnpm ---
if have fnm; then
  ok "FNM $(fnm --version 2>/dev/null | tr -d '\n')"
else
  err "fnm missing"
fi

if have node; then
  nv="$(node --version 2>/dev/null || true)"
  node_path="$(command -v node)"
  if [[ "$node_path" == *fnm* ]]; then
    ok "Node $nv via FNM"
  else
    warn "Node $nv not clearly under FNM path ($node_path)"
  fi
  if [[ "$nv" == v24.* ]]; then
    ok "Node major 24 (LTS policy)"
  else
    warn "Node not on v24.x: $nv"
  fi
else
  err "node not found"
fi

if have npm; then
  ok "npm $(npm --version 2>/dev/null)"
else
  err "npm not found"
fi

if have corepack; then
  ok "corepack $(corepack --version 2>/dev/null || echo present)"
else
  warn "corepack not found"
fi

if have pnpm; then
  ok "pnpm $(pnpm --version 2>/dev/null)"
else
  err "pnpm not found"
fi

# --- Angular ---
if have ng; then
  ag="$(ng version 2>/dev/null | awk -F': ' '/Angular CLI/{print $2; exit}' | tr -d ' ')"
  if [[ -n "$ag" ]]; then
    ok "Angular CLI $ag"
  else
    warn "ng present but version not parsed"
  fi
else
  warn "Angular CLI (ng) not found"
fi

# --- Flutter / Dart / FVM ---
if have flutter; then
  fl="$(flutter --version 2>/dev/null | head -1 || true)"
  fl_path="$(command -v flutter)"
  if [[ "$fl_path" == /opt/homebrew/bin/flutter ]]; then
    ok "Flutter via Homebrew ($fl)"
  else
    warn "Flutter not Homebrew primary: $fl_path ($fl)"
  fi
else
  err "flutter not found"
fi

if have dart; then
  ok "Dart $(dart --version 2>&1 | awk '{print $4; exit}')"
else
  err "dart not found"
fi

if have fvm; then
  fv="$(fvm --version 2>/dev/null | head -1 | tr -d '\n' || true)"
  fv_path="$(command -v fvm)"
  if [[ "$fv_path" == /opt/homebrew/bin/fvm ]]; then
    ok "FVM $fv via Homebrew"
  else
    warn "FVM path unexpected: $fv_path ($fv)"
  fi
else
  err "fvm not found"
fi

if [[ -d "$HOME/flutter" ]]; then
  warn "Legacy ~/flutter directory still present on disk"
else
  ok "No legacy ~/flutter directory"
fi

# --- Android ---
android_sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
if [[ -d "$android_sdk" ]]; then
  ok "Android SDK dir ($android_sdk)"
else
  warn "Android SDK directory missing: $android_sdk"
fi

if have adb; then
  adb_path="$(command -v adb)"
  if [[ "$adb_path" == *"Android/sdk/platform-tools/adb" ]]; then
    ok "ADB from Android SDK ($(adb version 2>&1 | awk '/Version/{print $2; exit}'))"
  else
    warn "ADB not from Android SDK: $adb_path"
  fi
else
  err "adb not found"
fi

# --- Docker ---
if have docker; then
  ok "Docker CLI $(docker --version 2>/dev/null | head -1)"
  if docker info >/dev/null 2>&1; then
    ok "Docker daemon reachable"
  else
    warn "Docker daemon not running"
  fi
else
  err "docker CLI not found"
fi

# --- Editors ---
if [[ -d "/Applications/Cursor.app" ]]; then
  ok "Cursor.app present"
else
  err "Cursor.app missing"
fi
if have cursor; then
  ok "cursor CLI $(cursor --version 2>/dev/null | head -1)"
else
  err "cursor CLI missing"
fi

if [[ -d "/Applications/Visual Studio Code.app" ]]; then
  ok "VS Code.app present"
else
  err "VS Code.app missing"
fi
if have code; then
  ok "code CLI $(code --version 2>/dev/null | head -1)"
else
  err "code CLI missing"
fi

# --- Dotfiles structure ---
for req in Brewfile install.sh update.sh doctor.sh editor/shared/settings.base.json \
  editor/cursor/settings.json editor/vscode/settings.json \
  scripts/apply-editor-settings.sh scripts/install-editor-extensions.sh \
  zsh/.zshrc zsh/paths.zsh; do
  if [[ -e "$DOTFILES/$req" ]]; then
    ok "dotfiles: $req"
  else
    err "dotfiles missing: $req"
  fi
done

if [[ -f "$DOTFILES/Brewfile" ]] && grep -q 'visual-studio-code' "$DOTFILES/Brewfile"; then
  ok "Brewfile declares visual-studio-code"
else
  warn "Brewfile missing visual-studio-code"
fi

if [[ -f "$DOTFILES/Brewfile" ]] && grep -qE '^brew "node@' "$DOTFILES/Brewfile"; then
  err "Brewfile still declares Homebrew node formulae (policy: FNM only)"
else
  ok "Brewfile has no Homebrew node formulae"
fi

printf '\n=== summary ===\n'
printf 'errors=%s warnings=%s\n' "$ERRORS" "$WARNINGS"
if [[ "$ERRORS" -gt 0 ]]; then
  exit 1
fi
exit 0
