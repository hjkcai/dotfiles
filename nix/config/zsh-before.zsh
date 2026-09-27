if [ -f "$HOME/.zshrc-private" ]; then
  source "$HOME/.zshrc-private"
fi

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
  ZVM_ESCAPE_KEYTIMEOUT=0.2
}

function zvm_after_init() {
  bindkey -v '^[[A' up-line-or-beginning-search
  bindkey -v '^[[B' down-line-or-beginning-search
  source $ZSH_CUSTOM/plugins/fzf-zsh-plugin/fzf-zsh-plugin.plugin.zsh
  export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
    --color fg:#D8DEE9,bg:#2E3440,hl:#A3BE8C,fg+:#D8DEE9,bg+:#434C5E,hl+:#A3BE8C
    --color pointer:#BF616A,info:#4C566A,spinner:#4C566A,header:#4C566A,prompt:#81A1C1,marker:#EBCB8B'
}
