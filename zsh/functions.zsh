mkcd() {
  mkdir -p "$1" && cd "$1"
}

cproj() {
  local project

  project="$(find "$HOME/Projetos" -mindepth 1 -maxdepth 3 -type d 2>/dev/null |
    fzf)"

  if [ -n "$project" ]; then
    cd "$project" || return
    cursor .
  fi
}