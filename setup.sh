#!/bin/bash

# Globals
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
NEOVIM_VERSION="v0.11.4"
NEOVIM_PKG="nvim-linux-x86_64"
NVM_VERSION="v0.39.1"
NODE_VERSION="v24.7.0"

# Helpers 
link_bak () { # Link with backup ($1: Target, $2: Replacement)
	if [[ -L $1 || -f $1 ||  -d $1 ]]; then
		sudo mv -f $1 $1.bak
	fi

	echo "Linking $SCRIPT_DIR/$2 -> $1"
	ln -s $SCRIPT_DIR/$2 $1
}

bak () { # Move file to backup ($1: Target)
	if [[ -L $1 || -f $1 || -d $1 ]]; then
		echo "Backing up $1 to $1.bak"
		sudo mv -f $1 $1.bak
	fi
}

# Actions
## Install APT Packages
pkg_install () {
	if [ ! -f /etc/debian_version ]; then
		2>& echo "Package manager expects a Debian-based distribution!"
		2>& echo "Install the packages from $SCRIPT_DIR/.packages using your package manager."
		exit 1
	fi

	echo "Installing packages required by dotfiles"
	sudo apt update -y
	sudo apt install -y $(cat $SCRIPT_DIR/packages.txt)
}

## Install Neovim
nvim_install () {
	curl -LO https://github.com/neovim/neovim/releases/download/$NEOVIM_VERSION/$NEOVIM_PKG.tar.gz
	bak /opt/$NEOVIM_PKG
	sudo tar -C /opt -xzf $NEOVIM_PKG.tar.gz
	sudo rm -f $NEOVIM_PKG.tar.gz
	bak /usr/bin/nvim
    bak /usr/bin/vim
	bak /usr/bin/vi
	sudo ln -s /opt/$NEOVIM_PKG/bin/nvim /usr/bin/vim
	sudo ln -s /opt/$NEOVIM_PKG/bin/nvim /usr/bin/nvim
	sudo ln -s /opt/$NEOVIM_PKG/bin/nvim /usr/bin/vi

	sudo rm -rf $SCRIPT_DIR/.config/nvim/lazy
	git clone --filter=blob:none https://github.com/folke/lazy.nvim.git $SCRIPT_DIR/.config/nvim/lazy/lazy.nvim
}

## Install Node and Required Packages
install_node () {
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" 
    nvm install $NODE_VERSION
    nvm use $NODE_VERSION
    npm install -g pyright
}


## Link Configurations in Home
link_configs () {
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

pkg_install
nvim_install
link_configs
install_node

