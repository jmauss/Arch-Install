# Created by jmauss

autoload -Uz compinit
compinit

zstyle ':completion:*' menu select

zstyle ':completion:*' matcher-list '' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' \
  '+l:|?=** r:|?=**'

setopt HIST_IGNORE_DUPS

autoload -Uz colors && colors

#i3
PROMPT="[%{$fg_bold[green]%}%n%{$reset_color%}:%~%{$reset_color%}]$ "
#Non-i3
#PROMPT="[%{$fg_bold[green]%}%n%{$reset_color%}:%{$fg_no_bold[white]%}%~%{$reset_color%}]$ " 

autoload -U history-search-end

zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end

bindkey "\e[A" history-beginning-search-backward-end
bindkey "\e[B" history-beginning-search-forward-end

HISTSIZE=1000
if (( ! EUID )); then
  HISTFILE=~/.history_root
else
  HISTFILE=~/.history
fi
SAVEHIST=1000

export EDITOR=/usr/bin/vi

alias ls='ls --color=auto'
alias please='sudo $(fc -ln -1)'
alias sudo='sudo '
#alias msfconsole="msfconsole -x \"db_connect ${USER}@msf\""
#alias mirror-update="sudo reflector --sort rate -p https --save /etc/pacman.d/mirrorlist -c \"United States\" -f 5 -l 5"
