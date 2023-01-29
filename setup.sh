# Setup script for new machines
function section {
  echo
  echo -e "\033[0;31m${1}\033[0m"
}

function hasCommand {
  type $1 > /dev/null 2>&1
  return $?
}

if [ "$CHINA_MAINLAND" != '0' ]; then
  GITHUB=ghproxy.com/https://github.com
  GITHUB_RAW=ghproxy.com/https://raw.githubusercontent.com
else
  GITHUB=github.com
  GITHUB_RAW=raw.githubusercontent.com
fi

# Checks
if [ "$USER" = "root" ]; then
  echo "You cannot run this script as root. Remember to install sudo firstly."
  exit 1
fi

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
if ! [ -z "$GIT_NAME" ]; then
  echo -n 'Email: '
  read GIT_EMAIL
fi

# Locale & Timezone
section "Setting locale and timezone..."
sudo bash -c "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen"
sudo locale-gen
sudo localectl set-locale LANG=en_US.UTF-8
sudo timedatectl set-timezone Asia/Shanghai

# Arch Linux
if hasCommand "pacman"; then
  # China mirror
  if [ "$CHINA_MAINLAND" != '0' ]; then
    section "Switching to pacman China mirror..."
    sudo reflector -l 5 -c China -p https --sort rate --save /etc/pacman.d/mirrorlist
  fi

  # Keyring
  section "Initializing Keyring..."
  sudo pacman-key --init
  sudo pacman-key --populate archlinux
  sudo sudo pacman -Sy --noconfirm archlinux-keyring

  # Recommended packages
  section "Installing basic packages..."
  sudo pacman -S --noconfirm --needed \
    git base-devel man wget exa broot htop zsh docker docker-compose tmux neovim bat duf \
    ncdu unzip neofetch vim rsync nmap net-tools man-db lsof dog tldr httpie cronie fd sd p7zip

  # Docker
  section "Enabling Docker..."
  if [ "$CHINA_MAINLAND" != '0' ]; then
    sudo mkdir -p /etc/docker
    sudo bash -c "echo '{\"registry-mirrors\": [\"https://docker.mirrors.ustc.edu.cn/\"]}' > /etc/docker/daemon.json"
  fi

  sudo systemctl enable docker
  sudo systemctl start docker

  # Cronie
  section "Enabling Cronie..."
  sudo systemctl enable cronie
  sudo systemctl start cronie

  # yay
  if ! hasCommand "yay"; then
    section "Installing yay..."
    TEMP_DIR=`mktemp -u`
    git clone https://aur.archlinux.org/yay-bin.git $TEMP_DIR
    pushd $TEMP_DIR
      if [ "$CHINA_MAINLAND" != '0' ]; then
        sed -i "s|github.com|$GITHUB|g" PKGBUILD
      fi
      makepkg -si --noconfirm
    popd
  fi

  # ananicy
  if ! hasCommand "ananicy"; then
    section "Installing ananicy..."
    TEMP_DIR=`mktemp -u`
    git clone https://aur.archlinux.org/minq-ananicy-git.git $TEMP_DIR
    pushd $TEMP_DIR
      if [ "$CHINA_MAINLAND" != '0' ]; then
        sed -i "s|git+https\\://github.com|git+https\://$GITHUB|" PKGBUILD
      fi
      makepkg -si --noconfirm
      sudo systemctl enable ananicy
      sudo systemctl start ananicy
    popd
  fi
fi

# Git
if ! [ -z "$GIT_NAME" ]; then
  section "Setting up Git..."
  git config --global user.name $GIT_NAME
  git config --global user.email $GIT_EMAIL
  git config --global pull.rebase 'false'
  git config --global credential.helper store
fi

# oh-my-zsh
if ! [ -d $HOME/.oh-my-zsh ]; then
  section "Installing oh-my-zsh..."
  sudo chsh -s /usr/bin/zsh $USER
  curl -fsSL https://$GITHUB_RAW/ohmyzsh/ohmyzsh/master/tools/install.sh > /tmp/oh-my-zsh
  if [ "$CHINA_MAINLAND" != '0' ]; then
    sed -i "s|github.com|$GITHUB|g" /tmp/oh-my-zsh
  fi
  RUNZSH=no bash /tmp/oh-my-zsh

  section "Installing oh-my-zsh plugins..."
  ZSH_CUSTOM=$HOME/.oh-my-zsh/custom
  git clone https://$GITHUB/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
  git clone https://$GITHUB/zdharma-continuum/fast-syntax-highlighting.git $ZSH_CUSTOM/plugins/fast-syntax-highlighting
  git clone https://$GITHUB/unixorn/fzf-zsh-plugin.git $ZSH_CUSTOM/plugins/fzf-zsh-plugin
  git clone https://$GITHUB/Aloxaf/fzf-tab.git $ZSH_CUSTOM/plugins/fzf-tab

  # fzf
  git clone --depth 1 https://$GITHUB/junegunn/fzf.git $HOME/.fzf
  if [ "$CHINA_MAINLAND" != '0' ]; then
    sed -i "s|github.com|$GITHUB|g" $HOME/.fzf/install
  fi
  $HOME/.fzf/install --bin

  # agkozak zsh theme
  [[ ! -d $ZSH_CUSTOM/themes ]] && mkdir $ZSH_CUSTOM/themes
  git clone https://$GITHUB/agkozak/agkozak-zsh-prompt $ZSH_CUSTOM/themes/agkozak
  ln -s $ZSH_CUSTOM/themes/agkozak/agkozak-zsh-prompt.plugin.zsh $ZSH_CUSTOM/themes/agkozak.zsh-theme
fi

# broot
section "Installing broot..."
if hasCommand "broot"; then
  zsh -c 'broot --install'
  curl https://$GITHUB_RAW/kreigor/broot-nord-theme/main/broot.skin > $HOME/.config/broot/nord.toml
  sed -i "s|dark-blur-skin.hjson|nord.toml" $HOME/.config/broot/config.hjson
fi

# zsh config
section "Installing zsh config..."
echo "CHINA_MAINLAND=${CHINA_MAINLAND:-1}\n" > $HOME/.zshrc
curl https://$GITHUB_RAW/hjkcai/dotfiles/master/zshrc >> $HOME/.zshrc

# tmux config
section "Installing tmux config..."
mkdir -p $HOME/.config/tmux
curl https://$GITHUB_RAW/hjkcai/dotfiles/master/tmux.conf > $HOME/.config/tmux/tmux.conf

# Node.js
if ! [ -d $HOME/.n ]; then
  section "Installing tj/n and Node.js..."
  export N_PREFIX=$HOME/.n
  curl -L https://$GITHUB_RAW/mklement0/n-install/stable/bin/n-install > /tmp/n-install

  if [ "$CHINA_MAINLAND" != '0' ]; then
    export N_NODE_MIRROR=https://registry.npmmirror.com/mirrors/node
    sed -i "s|https\://github.com|https\://$GITHUB|g" /tmp/n-install
  fi

  bash /tmp/n-install -n -y lts
  export PATH=$PATH:$N_PREFIX/bin

  if [ "$CHINA_MAINLAND" != '0' ]; then
    section "Setting npm registry..."
    npm config set registry ${NPM_REGISTRY:-https://registry.npmmirror.com}
  fi
fi

# Node packages
section "Installing common Node.js packages..."
npm install -g \
  concurrently create-react-app http-server lerna \
  npm-check-updates nodemon pm2 ts-node whistle yarn pnpm esno

section "Enjoy!"
neofetch
