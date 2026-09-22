# Shortcut for common tool use

# Open fzf file in vim
function vzf () { 
    file=$(fzf)
    vi $file
}

if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
else
  alias vim='vim'
fi

# Find a port and kill the process using it
function pok () {
    if [ -z "$1" ]; then
        echo "Usage: pf <port>"
        return 1
    fi
    lsof -i :$1
    if [ $? -eq 0 ]; then
        echo "Killing process on port $1"
        lsof -t -i :$1 | xargs kill -9
    else
        echo "No process found on port $1"
    fi
}

# Refresh page cache for profiling
function rpc () {
    sync && echo 3 | sudo tee /proc/sys/vm/drop_caches
}

# Refresh dns
function rdns () {
    sudo resolvectl flush-caches
    sudo systemctl restart systemd-resolved
}
