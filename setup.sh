# Setup script for new machines

# Hostname
echo "Please enter your new HOSTNAME (Currently '$HOSTNAME'). Leave it empty to skip."
echo -n "HOSTNAME: "
read NEW_HOSTNAME
if ! [ -z "$NEW_HOSTNAME" ]; then
  sudo hostnamectl set-hostname $NEW_HOSTNAME
fi

# Git (Ask first)
echo -n 'Git user name: '
read GIT_NAME
echo -n 'Git email: '
read GIT_EMAIL

# Locale & Timezone
echo "Setting locale and timezone..."
sudo echo "en_US.UTF-8" > /etc/locale.gen
sudo locale-gen
sudo localectl set-locale LANG=en_US.UTF-8
sudo timedatectl set-timezone Asia/Shanghai

# Arch Linux
if type "pacman" > /dev/null; then
  # China mirror
  echo "Switching to pacman China mirror..."
  sudo reflector -l 5 -c China -p https --sort rate --save /etc/pacman.d/mirrorlist

  # Recommended packages
  echo "Installing basic packages..."
  pacman -Sy --noconfirm --needed \
    git base-devel man wget exa broot htop zsh docker docker-compose \
    ncdu unzip neofetch vim rsync nmap net-tools man-db lsof

  # Docker
  echo "Enabling Docker..."
  sudo echo '{"registry-mirrors": ["https://docker.mirrors.ustc.edu.cn/"]}' > /etc/docker/daemon.json
  sudo systemctl enable docker
  sudo systemctl start docker

  # yay
  echo "Installing yay..."
  if ! type "yay" > /dev/null; then
    TEMP_DIR=`mktemp`
    git clone https://aur.archlinux.org/yay.git $TEMP_DIR
    pushd $TEMP_DIR
      sed 's/github.com/download.fastgit.org/g' PKGBUILD
      makepkg -si --noconfirm
    popd
  fi

  # ananicy
  echo "Installing ananicy..."
  if ! type "ananicy" > /dev/null; then
    TEMP_DIR=`mktemp`
    git clone https://aur.archlinux.org/ananicy-git.git $TEMP_DIR
    pushd $TEMP_DIR
      sed 's/git+https\:\/\/github.com/git+https\:\/\/hub.fastgit.xyz/' PKGBUILD
      makepkg -si --noconfirm
      sudo systemctl enable ananicy
      sudo systemctl start ananicy
    popd
  fi
fi

# Git
git config --global user.name $GIT_NAME
git config --global user.email $GIT_EMAIL
git config --global pull.rebase 'false'
git config --global credential.helper store

# oh-my-zsh
if ! [ -d ~/.oh-my-zsh ]; then
  echo "Installing oh-my-zsh..."
  RUNZSH=no bash -c "$(curl -fsSL https://raw.fastgit.org/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  echo "Installing oh-my-zsh and its plugins..."
  ZSH_CUSTOM=~/.oh-my-zsh/custom
  git clone https://hub.fastgit.xyz/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
  git clone https://hub.fastgit.xyz/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions

  # agkozak zsh theme
  [[ ! -d $ZSH_CUSTOM/themes ]] && mkdir $ZSH_CUSTOM/themes
  git clone https://hub.fastgit.xyz/agkozak/agkozak-zsh-prompt $ZSH_CUSTOM/themes/agkozak
  ln -s $ZSH_CUSTOM/themes/agkozak/agkozak-zsh-prompt.plugin.zsh $ZSH_CUSTOM/themes/agkozak.zsh-theme
fi

# zsh config
echo "Installing zsh config..."
curl https://raw.fastgit.org/hjkcai/dotfiles/master/zshrc > $HOME/.zshrc

# Node.js
if ! [ -d ~/.n ]; then
  echo "Installing tj/n and Node.js..."
  export N_NODE_MIRROR=https://npm.taobao.org/mirrors/node
  export N_PREFIX=$HOME/.n
  curl -L https://git.io/n-install | bash -s -- -n -y latest

  echo "Setting npm registry..."
  npm config set registry ${NPM_REGISTRY:-https://registry.npm.taobao.org}
fi

# Node packages
echo "Installing common Node.js packages"
npm install -g \
  concurrently create-react-app @feflow/cli http-server lerna \
  npm-check-update nodemon pm2 ts-node typescript whistle yarn

echo "Enjoy!"
neofetch
exec zsh
