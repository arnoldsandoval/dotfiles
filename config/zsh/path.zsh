# path.zsh — PATH assembly. Everything $HOME-relative and existence-guarded.

typeset -U path  # dedupe

for _d in \
  "$HOME/.local/bin" \
  "$HOME/bin" \
  "$HOME/.bun/bin" \
  "$HOME/.cargo/bin" \
  "$HOME/go/bin" \
  "$HOME/go-sdk/go/bin" \
  "/usr/local/sbin"
do
  [[ -d $_d ]] && path=("$_d" $path)
done
unset _d
export PATH
