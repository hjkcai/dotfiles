# Setup script for new machines

# oh-my-zsh
# TODO
curl https://raw.githubusercontent.com/hjkcai/dotfiles/master/zshrc > $HOME/.zshrc

# Node.js
echo Installing tj/n
export N_NODE_MIRROR=https://npm.taobao.org/mirrors/node
export N_PREFIX=$HOME/.n
curl -L https://git.io/n-install | bash -s -- -n -y latest

# yarn
export PATH=$N_PREFIX/bin:$PATH
# TODO
