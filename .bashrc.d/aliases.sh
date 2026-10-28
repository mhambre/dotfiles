##############
##  Aliases ##
##############
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
  alias vi='vim'
else
  alias vim='vim'
  alias vi='vim'
fi

# Git aliases
alias it="git"
alias got="git"
alias gpfo="git push --force origin"
alias gpo="git push origin"
alias gd="git fetch"
alias gmo="git pull --no-rebase origin master"

alias src="source ~/.bashrc"
alias la="ls -la"
alias lg="lazygit"
alias k9="kill -9"
