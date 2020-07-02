# Setup script for new machines

# oh-my-zsh
RUNZSH=no sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
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
