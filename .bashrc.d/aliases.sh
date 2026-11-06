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
alias gf="git fetch"
gmo() {
    local default_branch
    default_branch=$(git ls-remote --symref origin HEAD | awk '/^ref:/ {sub(".*/", "", $2); print $2}')
    
    if [ -n "$default_branch" ]; then
        git pull --no-rebase origin "$default_branch"
    else
        echo "Error: Could not automatically determine the remote default branch." >&2
        return 1
    fi
}

alias src="source ~/.bashrc"
alias la="ls -la"
alias lg="lazygit"
alias k9="kill -9"

# Universal unix locations
alias cdp="cp ~/.agents/prompts/"
