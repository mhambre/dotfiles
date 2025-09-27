# linfigurator
Linux autoconfiguration script for quickly deploying to a new development environment. This is tailored to Gnome, and will work on Fedora and Debian-based distributions.

## Installs/Configures
- NeoVim
- Tmux
- VSCode
- Tabby
- NerdFont
- [Development Packages](./packages.txt)

## How to Run
1. In a location of your choosing clone the repository with `git clone https://github.com/matthambrecht/linfigurator.git`.
2. Copy the contents of `env_template` to a file called `.env` in the project directory and update the version strings in it if necessary.
3. Run the setup script with `./setup`.
4. The setup script will backup the existing dotfiles and configurations that would otherwise be overwritten, then symlink the new ones from this directory to the installing user's home directory.

## Suggestions
- After initial install, make changes manually.
- Do not delete the install directory, if you do the symlinks will be broken.
- Probably don't install this, this is tailored to my development flow, I suggest figuring out what works for you as you go. 
