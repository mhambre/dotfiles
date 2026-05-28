# Shortcut for common tool use
alias src="source ~/.bashrc"
alias la="ls -la"
alias lg="lazygit"
function vzf () { # Open fzf file in vim
    file=$(fzf)
    vi $file
}
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
else
  alias vim='vim'
fi
