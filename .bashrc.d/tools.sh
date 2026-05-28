# Shortcut for common tool use
alias lg="lazygit"
function vzf () { # Open fzf file in vim
    file=$(fzf)
    vi $file
}

