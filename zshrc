# PATH
export PATH=$HOME/.local/bin:$HOME/.bin:$PATH

# Node.js related
if [ -d "$HOME/.n" ]; then
  export N_PREFIX=$HOME/.n

  # Assuming yarn is installed in the default location if Node.js is installed
  export PATH=$HOME/.config/yarn/global/node_modules/.bin:$N_PREFIX/bin:$PATH
fi

# z
alias zl="z -l"
alias zc="z -c"

# exa
alias ls="exa"
alias l="exa -lF --time-style=long-iso"
alias ll="exa -lhF --time-style=long-iso --git"
alias la="exa -lhHigUmuSa --time-style=long-iso --git --color-scale"
alias tree="exa --tree --level=2"

# npm
alias ni="tnpm i"
alias nid="tnpm i -D"
alias nig="tnpm i -g"
alias nr="tnpm run"
alias np="tnpm publish"
alias nu="tnpm uninstall"
alias nrb="tnpm run build"
alias nrd="tnpm run dev"
alias nrl="tnpm run lint"
alias nrlf="tnpm run lint -- --fix"
alias nrt="tnpm run test"
alias nrtc="tnpm run test -- --coverage"
alias nrtw="tnpm run test -- --watch"

alias npmc="npm --registry=https://registry.npm.taobao.org"
alias yarnc="yarn --registry=https://registry.npm.taobao.org"

function npm-link() {
  module="./node_modules/$1"
  rm -r $module
  ln -s $2 $module
}

# TypeScript
alias tscp="tsc -p ."
alias tscpw="tsc -p . -w"
alias tscpp="tsc -p tsconfig.prod.json"
alias tscppw="tsc -p tsconfig.prod.json -w"

# adb
alias adb-scr="adb exec-out screencap -p"
alias adb-scrcpy="adb exec-out screencap -p | impbcopy -"
alias adb-deeplink="adb shell am start -W -a android.intent.action.VIEW -d"
alias adb-paste="adb shell am broadcast -a clipper.get"
alias adb-copy="adb shell am broadcast -a clipper.set -e text"
alias adb-kill="adb shell am force-stop"

# Haskell Stack
if type "stack" > /dev/null; then
  alias sr="stack run"
  alias sb="stack build"
  alias srs="stack run --silent"
  alias sghci="stack ghci"

  autoload -U +X compinit && compinit
  autoload -U +X bashcompinit && bashcompinit
  eval "$(stack --bash-completion-script stack)"
fi

# Flutter
if type "flutter" > /dev/null; then
  export PUB_HOSTED_URL=https://pub.flutter-io.cn
  export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
fi

# Proxies
alias unset-proxy="unset http_proxy && unset https_proxy"
alias ioa-proxy="export http_proxy=http://127.0.0.1:12639 && export https_proxy=http://127.0.0.1:12639"
alias ss-proxy="export http_proxy=http://127.0.0.1:1080 && export https_proxy=http://127.0.0.1:1080"
alias clash-proxy="export http_proxy=http://127.0.0.1:7890 && export https_proxy=http://127.0.0.1:7890"

# MacOS
alias jitouch="killall Jitouch; open $HOME/Library/PreferencePanes/Jitouch.prefPane/Contents/Resources/Jitouch.app"
alias show-hidden="chflags nohidden"
alias hide-hidden="chflags hidden"

# Other
export N_NODE_MIRROR=https://npm.taobao.org/mirrors/node
alias ports-usage="lsof -i -P -sTCP:LISTEN"

# oh-my-zsh config
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="agkozak"
DISABLE_AUTO_UPDATE="true"
plugins=(git sudo node npm macos extract z zsh-syntax-highlighting zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# Customization for the theme agkozak
AGKOZAK_CUSTOM_PROMPT=$'%(!.%S%B.%B%F{green})%n%1v%(!.%b%s.%f%b) '
AGKOZAK_CUSTOM_PROMPT+='%B%F{blue}%2v%f%b'
AGKOZAK_CUSTOM_PROMPT+=$'%(3V.%F{243}%3v%f.)\n'
AGKOZAK_CUSTOM_PROMPT+='%(4V.:.%(!.#.$)) '
AGKOZAK_CUSTOM_RPROMPT=$'%{\e[1A%}%(?..%B%F{red}(%?%)%f%b )%F{243}%*%f%{\e[1B%}'

AGKOZAK_PROMPT_DIRTRIM=4
AGKOZAK_BLANK_LINES=1
AGKOZAK_CUSTOM_SYMBOLS=( '↓↑' '↓' '↑' '+' 'x' '*' '>' '?' 'S')
AGKOZAK_FORCE_ASYNC_METHOD=none

# Private
if [ -f "$HOME/.zshrc-private" ]; then
  source "$HOME/.zshrc-private"
fi
