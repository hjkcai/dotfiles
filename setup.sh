# Setup script for new machines

# oh-my-zsh
# TODO
curl https://raw.githubusercontent.com/hjkcai/dotfiles/master/zshrc > $HOME/.zshrc

# agkozak zsh theme
[[ ! -d $ZSH_CUSTOM/themes ]] && mkdir $ZSH_CUSTOM/themes
git clone https://github.com/agkozak/agkozak-zsh-prompt $ZSH_CUSTOM/themes/agkozak
ln -s $ZSH_CUSTOM/themes/agkozak/agkozak-zsh-prompt.plugin.zsh $ZSH_CUSTOM/themes/agkozak.zsh-theme

# Node.js
echo Installing tj/n
export N_NODE_MIRROR=https://npm.taobao.org/mirrors/node
export N_PREFIX=$HOME/.n
curl -L https://git.io/n-install | bash -s -- -n -y latest

# yarn
export PATH=$N_PREFIX/bin:$PATH
# TODO
