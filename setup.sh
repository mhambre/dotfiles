#!/bin/bash


# Globals
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
. $SCRIPT_DIR/.env >/dev/null 2>&1 || { >&2 echo "Missing environment file!"; exit 1; }

# Helpers 
link_bak () { # Link with backup ($1: Target, $2: Replacement)
    # Remove old backup
	if [[ -L $1.bak || -f $1.bak || -d $1.bak ]]; then
        rm -rf $1.bak
    fi

	if [[ -L $1 || -f $1 ||  -d $1 ]]; then
		echo " > Backing up $1 to $1.bak"
		sudo mv -f $1 $1.bak
	fi

	echo " > Linking $SCRIPT_DIR/$2 -> $1"
	ln -s $SCRIPT_DIR/$2 $1
}

bak () { # Move file to backup ($1: Target)
    # Remove old backup
	if [[ -L $1.bak || -f $1.bak || -d $1.bak ]]; then
        rm -rf $1.bak
    fi

	if [[ -L $1 || -f $1 || -d $1 ]]; then
		echo " > Backing up $1 to $1.bak"
		sudo mv -f $1 $1.bak
	fi
}

# Actions
## Install APT Packages
install_packages () {
	if [ ! -f /etc/debian_version ]; then
		>&2 echo "Package manager expects a Debian-based distribution!"
		>&2 echo "Install the packages from $SCRIPT_DIR/.packages using your package manager."
		exit 1
	fi

	echo "Installing System Packages..."
	sudo apt -o Apt::Cmd::Disable-Script-Warning=true update -y 2>&1 >/dev/null
	sudo apt -o Apt::Cmd::Disable-Script-Warning=true install -y $(cat $SCRIPT_DIR/packages.txt) 2>&1 >/dev/null
}

## Install Neovim
install_nvim () {
    echo "Installing NeoVim..."

	curl -s -LO https://github.com/neovim/neovim/releases/download/$NEOVIM_VERSION/$NEOVIM_PKG.tar.gz 2>&1 >/dev/null
	bak /opt/$NEOVIM_PKG
	sudo tar -C /opt -xzf $NEOVIM_PKG.tar.gz 2>&1 >/dev/null
	sudo rm -f $NEOVIM_PKG.tar.gz
	bak /usr/bin/nvim
    bak /usr/bin/vim
	bak /usr/bin/vi
	sudo ln -s /opt/$NEOVIM_PKG/bin/nvim /usr/bin/vim
	sudo ln -s /opt/$NEOVIM_PKG/bin/nvim /usr/bin/nvim
	sudo ln -s /opt/$NEOVIM_PKG/bin/nvim /usr/bin/vi

	sudo rm -rf $SCRIPT_DIR/.config/nvim/lazy
	git clone --quiet --filter=blob:none https://github.com/folke/lazy.nvim.git $SCRIPT_DIR/.config/nvim/lazy/lazy.nvim >/dev/null 2>&1 || { >&2 echo "Couldn't install Lazy.nvim"; exit 1; }
}

## Install Node and Required Packages
install_node () {
    echo "Installing Node.JS..."
    curl -s -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash 2>&1 >/dev/null
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" 2>&1 >/dev/null # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 2>&1 >/dev/null
    nvm install $NODE_VERSION >/dev/null 2>&1 || { echo "Couldn't install Node.JS!"; exit 1; }
    nvm use $NODE_VERSION 2>&1 >/dev/null
    npm install -g pyright 2>&1 >/dev/null
}

## Install LazyGit
install_lazygit () {
    echo "Installing LazyGit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | \grep -Po '"tag_name": *"v\K[^"]*')
    curl -s -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf lazygit.tar.gz lazygit 2>&1 >/dev/null
    sudo install lazygit -D -t /usr/local/bin/ 2>&1 >/dev/null
    rm -rf lazygit.tar.gz lazygit
}

## Link Configurations in Home
install_configs () {
    echo "Adding Custom Dotfiles..."
    configs=(
        .tmux.conf
        .bashrc
        .config/nvim
        .config/tabby
    )

    for i in "${configs[@]}"; do
        link_bak ~/$i $i
    done
}

## System Configurations
config_system () {
    echo "Running Global System Configurations..."
    echo "setxkbmap -option caps:none" >> ~/.profile # No caps
}

cat <<EOF
┳┳┓    ╹   ┓ •        ┏┓    ┏•             
┃┃┃┏┓╋╋ ┏  ┃ ┓┏┓┓┏┓┏  ┃ ┏┓┏┓╋┓┏┓┓┏┏┓┏┓╋┏┓┏┓
┛ ┗┗┻┗┗ ┛  ┗┛┗┛┗┗┻┛┗  ┗┛┗┛┛┗┛┗┗┫┗┻┛ ┗┻┗┗┛┛ 
EOF

while true; do
    cat <<EOF
This script needs to be run after a fresh system install.
File's may be manually used and added if the install isn't
fresh, or in order to apply patches.
EOF

    read -p "Do you want to proceed? (y/n) " yn
    case $yn in
        [Yy]* ) 
            break;;
        [Nn]* ) 
            echo "Exiting..."
            exit;;
        * ) 
            echo "Invalid response. Please answer y or n.";;
    esac
done

install_packages &&
install_nvim &&
install_configs &&
install_node &&
install_lazygit &&
config_system
