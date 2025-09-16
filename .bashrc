#!/bin/bash

##############
##  Aliases ##
##############
if command -v nvim >/dev/null 2>&1; then
  alias vim='nvim'
else
  alias vim='vim'
fi

#################
## Global Prep ##
#################
if [ -f /etc/bashrc ]; then
	 . /etc/bashrc
fi

if [ -f /usr/share/bash-completion/bash_completion ]; then
	. /usr/share/bash-completion/bash_completion
elif [ -f /etc/bash_completion ]; then
	. /etc/bash_completion
fi

#####################
## Default Exports ##
#####################
interactive=$(expr index "$-" i)
export HISTFILESIZE=10000
export HISTSIZE=500
export HISTCONTROL=erasedups:ignoredups:ignorespace
shopt -s checkwinsize
shopt -s histappend
PROMPT_COMMAND='history -a'
stty -ixon
if [[ $interactive -gt 0 ]]; then bind "set completion-ignore-case on"; fi
if [[ $interactive -gt 0 ]]; then bind "set show-all-if-ambiguous On"; fi

# Set the default editor
export EDITOR=$(command -v nvim >/dev/null 2>&1 && echo nvim || echo vim)
export VISUAL=$(command -v nvim >/dev/null 2>&1 && echo nvim || echo vim)

# Colors for ls and grep* 
export CLICOLOR=1
export LS_COLORS='no=00:fi=00:di=00;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:ex=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.avi=01;35:*.fli=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.ogg=01;35:*.mp3=01;35:*.wav=01;35:*.xml=00;31:'
alias grep="/usr/bin/grep $GREP_OPTIONS"
unset GREP_OPTIONS

# Color for manpages in less
export LESS_TERMCAP_mb=$'\E[01;31m'
export LESS_TERMCAP_md=$'\E[01;31m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[01;32m'

############
## Prompt ##
############
function __setprompt
{
	local LAST_COMMAND=$? # Must come first!

	# Define colors
	local LIGHTGRAY="\033[0;37m"
	local WHITE="\033[1;37m"
	local BLACK="\033[0;30m"
	local DARKGRAY="\033[1;30m"
	local RED="\033[0;31m"
	local LIGHTRED="\033[1;31m"
	local GREEN="\033[0;32m"
	local LIGHTGREEN="\033[1;32m"
	local BROWN="\033[0;33m"
	local YELLOW="\033[1;33m"
	local BLUE="\033[0;34m"
	local LIGHTBLUE="\033[1;34m"
	local MAGENTA="\033[0;35m"
	local LIGHTMAGENTA="\033[1;35m"
	local CYAN="\033[0;36m"
	local LIGHTCYAN="\033[1;36m"
	local NOCOLOR="\033[0m"

	# Show error exit code if there is one
	if [[ $LAST_COMMAND != 0 ]]; then
		# PS1="\[${RED}\](\[${LIGHTRED}\]ERROR\[${RED}\])-(\[${LIGHTRED}\]Exit Code \[${WHITE}\]${LAST_COMMAND}\[${RED}\])-(\[${LIGHTRED}\]"
		PS1="\[${DARKGRAY}\](\[${LIGHTRED}\]ERROR\[${DARKGRAY}\])-(\[${RED}\]Exit Code \[${LIGHTRED}\]${LAST_COMMAND}\[${DARKGRAY}\])-(\[${RED}\]"
		if [[ $LAST_COMMAND == 1 ]]; then
			PS1+="General error"
		elif [ $LAST_COMMAND == 2 ]; then
			PS1+="Missing keyword, command, or permission problem"
		elif [ $LAST_COMMAND == 126 ]; then
			PS1+="Permission problem or command is not an executable"
		elif [ $LAST_COMMAND == 127 ]; then
			PS1+="Command not found"
		elif [ $LAST_COMMAND == 128 ]; then
			PS1+="Invalid argument to exit"
		elif [ $LAST_COMMAND == 129 ]; then
			PS1+="Fatal error signal 1"
		elif [ $LAST_COMMAND == 130 ]; then
			PS1+="Script terminated by Control-C"
		elif [ $LAST_COMMAND == 131 ]; then
			PS1+="Fatal error signal 3"
		elif [ $LAST_COMMAND == 132 ]; then
			PS1+="Fatal error signal 4"
		elif [ $LAST_COMMAND == 133 ]; then
			PS1+="Fatal error signal 5"
		elif [ $LAST_COMMAND == 134 ]; then
			PS1+="Fatal error signal 6"
		elif [ $LAST_COMMAND == 135 ]; then
			PS1+="Fatal error signal 7"
		elif [ $LAST_COMMAND == 136 ]; then
			PS1+="Fatal error signal 8"
		elif [ $LAST_COMMAND == 137 ]; then
			PS1+="Fatal error signal 9"
		elif [ $LAST_COMMAND -gt 255 ]; then
			PS1+="Exit status out of range"
		else
			PS1+="Unknown error code"
		fi
		PS1+="\[${DARKGRAY}\])\[${NOCOLOR}\]\n"
	else
		PS1=""
	fi

	# Date or Venv
	if [[ -z "${VIRTUAL_ENV}" ]]; then
		PS1+="\[${CYAN}\] \$(date +%a) $(date +%b-'%-m')" # Date
		PS1+="${BLUE}  $(date +'%-I':%M:%S%P)\[${DARKGRAY}\] 󰐊 " # Time
	else
		PS1+="\[${CYAN}\] `basename $VIRTUAL_ENV`\[${DARKGRAY}\] 󰐊 "
	fi

	# Username
	local SSH_IP=`echo $SSH_CLIENT | awk '{ print $1 }'`
	local SSH2_IP=`echo $SSH2_CLIENT | awk '{ print $1 }'`
	if [ $SSH2_IP ] || [ $SSH_IP ] ; then
		PS1+="\[${RED}\] \u@\h "
	else
		PS1+="\[${RED}\] \u "
	fi	

	# Current directory
	PS1+="\[${BROWN}\] \w\[${DARKGRAY}\] 󰐊 "

	if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
		# Git info
		PS1+="\[${GREEN}\]󰊢 $(basename $(git rev-parse --show-toplevel)) "
		PS1+="\[${YELLOW}\] $(git rev-parse --abbrev-ref HEAD)\[${DARKGRAY}\]"
	else
		# File info
		PS1+="\[${GREEN}\] $(/bin/ls -lah | /bin/grep -m 1 total | /bin/sed 's/total //') "
		PS1+="\[${GREEN}\] \$(/bin/ls -A -1 | /usr/bin/wc -l)\[${DARKGRAY}\]"
	fi	

	if [[ $EUID -ne 0 ]]; then
		PS1+="\n\[${GREEN}\]  󰒊\[${NOCOLOR}\] " # Normal user
	else
		PS1+="\n\[${RED}\]  󰒊\[${NOCOLOR}\] " # Root user
	fi

	# PS2 is used to continue a command using the \ character
	PS2="\[${DARKGRAY}\]>\[${NOCOLOR}\] "
	PS3='Please enter a number from above list: '
	PS4='\[${DARKGRAY}\]+\[${NOCOLOR}\] '
}

PROMPT_COMMAND='__setprompt'
neofetch

# If not running interactively, don't do anything
case $- in
	*i*) ;;
	*) return ;;
esac
