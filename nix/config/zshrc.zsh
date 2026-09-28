export LANG=en_US.UTF-8

if [ "$CHINA_MAINLAND" != '0' ]; then
  export GITHUB=ghfast.top/https://github.com
  export GITHUB_RAW=ghfast.top/https://raw.githubusercontent.com
  export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com/
  export N_NODE_MIRROR=https://mirrors.ustc.edu.cn/node/
else
  export GITHUB=github.com
  export GITHUB_RAW=raw.githubusercontent.com
fi

function zvm_config() {
  ZVM_READKEY_ENGINE=$ZVM_READKEY_ENGINE_ZLE
  ZVM_KEYTIMEOUT=0.2
  ZVM_ESCAPE_KEYTIMEOUT=0.2 # so that EscEsc sudo will work
}

function zvm_after_init() {
  # Fix key conflicts
  bindkey -v '^[[A' up-line-or-beginning-search
  bindkey -v '^[[B' down-line-or-beginning-search

  # fzf & Nord theme
  source $ZSH_CUSTOM/plugins/fzf-zsh-plugin/fzf-zsh-plugin.plugin.zsh
  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
    --color fg:#D8DEE9,bg:#2E3440,hl:#A3BE8C,fg+:#D8DEE9,bg+:#434C5E,hl+:#A3BE8C
    --color pointer:#BF616A,info:#4C566A,spinner:#4C566A,header:#4C566A,prompt:#81A1C1,marker:#EBCB8B'

  # zvm_init runs from precmd, after `fzf --zsh`, and rebinds Ctrl-R.
  bindkey -M viins '^R' fzf-history-widget
  bindkey -M vicmd '^R' fzf-history-widget
}

###############################################################################
# {{HOME_MANAGER}}
###############################################################################

AGKOZAK_CUSTOM_PROMPT=$'%(!.%S%B.%B%F{green})%n%1v%(!.%b%s.%f%b) '
AGKOZAK_CUSTOM_PROMPT+='%B%F{blue}%2v%f%b'
AGKOZAK_CUSTOM_PROMPT+=$'%(3V.%F{243}%3v%f.)\n'
AGKOZAK_CUSTOM_PROMPT+='%(4V.:.%(!.#.$)) '
AGKOZAK_CUSTOM_RPROMPT=$'%{\e[1A%}%(?..%B%F{red}(%?%)%f%b )%F{243}%*%f%{\e[1B%}'
AGKOZAK_PROMPT_DIRTRIM=4
AGKOZAK_BLANK_LINES=1
AGKOZAK_CUSTOM_SYMBOLS=( '↓↑' '↓' '↑' '+' 'x' '*' '>' '?' 'S')
AGKOZAK_FORCE_ASYNC_METHOD=none

# bat
export BAT_THEME=Nord
alias cat="bat -pp"


# brootif command -v broot > /dev/null; then
  eval "$(broot --print-shell-function zsh)"
fi

# Rust cargo
if [ -f "$HOME/.cargo/env" ]; then
  . "$HOME/.cargo/env"
fi

alias ls="eza"
alias l="eza -lF --time-style=long-iso"
alias la="eza -lF --time-style=long-iso -a"
alias ll="eza -lhF --time-style=long-iso --git"
alias lla="eza -lhF --time-style=long-iso --git -a"
alias laa="eza -lhHigUmuSa --time-style=long-iso --git --color-scale"
alias tree="eza --tree --level=2"

# npm
alias npmc="npm --registry=https://registry.npmmirror.com"
alias ni="npm i"
alias nid="npm i -D"
alias nig="npm i -g"
alias nr="npm run"
alias np="npm publish"
alias nu="npm uninstall"
alias nrb="npm run build"
alias nrd="npm run dev"
alias nrl="npm run lint"
alias nrlf="npm run lint -- --fix"
alias nrt="npm run test"
alias nrtc="npm run test -- --coverage"
alias nrtw="npm run test -- --watch"

# pnpm
alias pi="pnpm i"
alias pid="pnpm i -D"
alias pig="pnpm i -g"
alias piw="pnpm i -w"
alias piwd="pnpm i -w -D"

# TypeScript
alias tscp="tsc -p ."
alias tscpw="tsc -p . -w"
alias tscpp="tsc -p tsconfig.prod.json"
alias tscppw="tsc -p tsconfig.prod.json -w"

# Jest
alias jest="npx jest"
alias jestb="npx jest --runInBand"
alias jestc="npx jest --coverage"
alias jestp="npx jest --testPathPattern"
alias jestbp="npx jest --runInBand --testPathPattern"

# adb
alias adb-scr="adb exec-out screencap -p"
alias adb-scrcpy="adb exec-out screencap -p | impbcopy -"
alias adb-deeplink="adb shell am start -W -a android.intent.action.VIEW -d"
alias adb-paste="adb shell am broadcast -a clipper.get"
alias adb-copy="adb shell am broadcast -a clipper.set -e text"
alias adb-kill="adb shell am force-stop"

# Helix
if command -v hx > /dev/null; then
  export EDITOR="hx"
  export VISUAL="hx"
elif command -v helix > /dev/null; then
  export EDITOR="helix"
  export VISUAL="helix"
  alias hx="helix"
fi

# Docker (Most aliases are set by zsh-docker-aliases)
alias dkcdu="docker-compose down && docker-compose up"
alias dkcdU="docker-compose down && docker-compose up -d"
alias dkclf="docker-compose logs -f --tail 100"

# Proxies
alias unset-proxy="unset http_proxy && unset https_proxy"
alias clash-proxy="export http_proxy=http://127.0.0.1:7890 && export https_proxy=http://127.0.0.1:7890"

# Other
alias ports-usage="lsof -i -P -sTCP:LISTEN"
alias hs="http-server"
alias sudo="sudo " # sudo magic: https://askubuntu.com/questions/22037/aliases-not-available-when-using-sudo
alias env="/usr/bin/env -0 | sort -z | tr '\0' '\n' | sd '(^|\n)([A-Za-z0-9_]+)=' \$(printf '\$1\033[1;32m\$2\033[0m=')"

tm() {
  tmux new-session -A -s ${1:-main}
}

# Ctrl-L clears buffer
clear-scrollback-and-screen() {
  echo -n -e '\e[2J\e[3J\e[1;1H'
  zle clear-screen
  tmux clear-history 2>/dev/null || true
}
zle -N clear-scrollback-and-screen
bindkey -v '^L' clear-scrollback-and-screen

# herdr-automatic-rename. Home Manager symlinks the pinned checkout into this directory.
for _f in ${HOME}/.config/herdr/plugins/github/herdr-automatic-rename-*/shell/hook.zsh(N); do
  source $_f
  break
done

# Private
if [ -f "$HOME/.zshrc-private" ]; then
  source "$HOME/.zshrc-private"
fi
