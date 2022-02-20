# Setup script for new machines
function section {
  echo
  echo -e "\033[0;31m${1}\033[0m"
}

# Hostname
section "Please enter your new HOSTNAME (Currently '$HOSTNAME'). Leave it empty to skip."
echo -n "HOSTNAME: "
read NEW_HOSTNAME
if ! [ -z "$NEW_HOSTNAME" ]; then
  sudo hostnamectl set-hostname $NEW_HOSTNAME
fi

# Git (Ask first)
section "Please enter your default Git information."
echo -n 'Username: '
read GIT_NAME
echo -n 'Email: '
read GIT_EMAIL

# Locale & Timezone
section "Setting locale and timezone..."
sudo bash -c "echo 'en_US.UTF-8' > /etc/locale.gen"
sudo locale-gen
sudo localectl set-locale LANG=en_US.UTF-8
sudo timedatectl set-timezone Asia/Shanghai

# Arch Linux
if type "pacman" > /dev/null; then
  # China mirror
  section "Switching to pacman China mirror..."
  sudo reflector -l 5 -c China -p https --sort rate --save /etc/pacman.d/mirrorlist

  # Recommended packages
  section "Installing basic packages..."
  pacman -Sy --noconfirm --needed \
    git base-devel man wget exa broot htop zsh docker docker-compose \
    ncdu unzip neofetch vim rsync nmap net-tools man-db lsof

  # Docker
  section "Enabling Docker..."
  sudo bash -c "echo '{\"registry-mirrors\": [\"https://docker.mirrors.ustc.edu.cn/\"]}' > /etc/docker/daemon.json"
  sudo systemctl enable docker
  sudo systemctl start docker

  # yay
  section "Installing yay..."
  if ! type "yay" > /dev/null; then
    TEMP_DIR=`mktemp`
    git clone https://aur.archlinux.org/yay.git $TEMP_DIR
    pushd $TEMP_DIR
      sed 's/github.com/download.fastgit.org/g' PKGBUILD
      makepkg -si --noconfirm
    popd
  fi

  # ananicy
  section "Installing ananicy..."
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
section "Setting up Git..."
git config --global user.name $GIT_NAME
git config --global user.email $GIT_EMAIL
git config --global pull.rebase 'false'
git config --global credential.helper store

# oh-my-zsh
if ! [ -d ~/.oh-my-zsh ]; then
  section "Installing oh-my-zsh..."
  RUNZSH=no bash -c "$(curl -fsSL https://raw.fastgit.org/ohmyzsh/ohmyzsh/master/tools/install.sh)"

  section "Installing oh-my-zsh and its plugins..."
  ZSH_CUSTOM=~/.oh-my-zsh/custom
  git clone https://hub.fastgit.xyz/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
  git clone https://hub.fastgit.xyz/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions

  # agkozak zsh theme
  [[ ! -d $ZSH_CUSTOM/themes ]] && mkdir $ZSH_CUSTOM/themes
  git clone https://hub.fastgit.xyz/agkozak/agkozak-zsh-prompt $ZSH_CUSTOM/themes/agkozak
  ln -s $ZSH_CUSTOM/themes/agkozak/agkozak-zsh-prompt.plugin.zsh $ZSH_CUSTOM/themes/agkozak.zsh-theme
fi

# zsh config
section "Installing zsh config..."
curl https://raw.fastgit.org/hjkcai/dotfiles/master/zshrc > $HOME/.zshrc

# Node.js
if ! [ -d ~/.n ]; then
  section "Installing tj/n and Node.js..."
  export N_NODE_MIRROR=https://npm.taobao.org/mirrors/node
  export N_PREFIX=$HOME/.n
  curl -L https://git.io/n-install | bash -s -- -n -y latest

  section "Setting npm registry..."
  npm config set registry ${NPM_REGISTRY:-https://registry.npm.taobao.org}
fi

# Node packages
section "Installing common Node.js packages"
npm install -g \
  concurrently create-react-app @feflow/cli http-server lerna \
  npm-check-update nodemon pm2 ts-node typescript whistle yarn

section "Enjoy!"
neofetch
exec zsh
