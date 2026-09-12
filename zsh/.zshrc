export DOTFILES="$HOME/dotfiles"

source "$DOTFILES/zsh/paths.zsh"
source "$DOTFILES/zsh/aliases.zsh"
source "$DOTFILES/zsh/functions.zsh"

if command -v brew >/dev/null 2>&1; then
  FNM_PATH="$(brew --prefix fnm 2>/dev/null)"

  if [ -d "$FNM_PATH" ]; then
    eval "$(fnm env --use-on-cd --shell zsh)"
  fi
fi

if [ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
  source "$HOME/.sdkman/bin/sdkman-init.sh"
fi