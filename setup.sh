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
  GITHUB=ghfast.top/https://github.com
  GITHUB_RAW=ghfast.top/https://raw.githubusercontent.com
else
  GITHUB=github.com
  GITHUB_RAW=raw.githubusercontent.com
fi

# Checks
if [ "$USER" = "root" ]; then echo "You cannot run this script as root. Remember to install sudo firstly."; exit 1; fi
if ! hasCommand "sudo"; then echo "Missing required command: sudo"; exit 1; fi

# Hostname
section "Please enter your new HOSTNAME (Currently '$HOSTNAME'). Leave it empty to skip."
echo -n "HOSTNAME: "
read NEW_HOSTNAME
if ! [ -z "$NEW_HOSTNAME" ]; then
  sudo hostnamectl set-hostname $NEW_HOSTNAME
fi

# Git (Ask first)
section "Please enter your default Git information. Leave it empty to skip."
echo -n 'Username: '
read GIT_NAME
if ! [ -z "$GIT_NAME" ]; then
  echo -n 'Email: '
  read GIT_EMAIL
fi

# Locale & Timezone
if hasCommand "locale-gen"; then
  section "Setting locale and timezone..."
  sudo bash -c "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen"
  sudo locale-gen
  sudo localectl set-locale LANG=en_US.UTF-8
  sudo timedatectl set-timezone Asia/Shanghai
fi

# Fedora & CentOS
if hasCommand "dnf"; then
  # Recommended packages
  section "Installing basic packages..."
  sudo dnf -y install git eza htop zsh docker docker-compose tmux bat duf ncdu unzip fastfetch rsync nmap lsof httpie cronie p7zip rhash jq helix cargo

  if [ "$CHINA_MAINLAND" != '0' ]; then
    mkdir -p ${CARGO_HOME:-$HOME/.cargo}

    cat << EOF | tee ${CARGO_HOME:-$HOME/.cargo}/config.toml
[source.crates-io]
replace-with = 'ustc'

[source.ustc]
registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"

[registries.ustc]
index = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
EOF
  fi

  cargo install broot fd-find sd

  # Docker
  section "Enabling Docker..."
  sudo systemctl enable --now docker
  sudo usermod -a -G docker $USER
  sudo docker network create apps
  if [ "$CHINA_MAINLAND" != '0' ]; then
    sudo mkdir -p /etc/systemd/system/docker.service.d
    cat << EOF | sudo tee /etc/systemd/system/docker.service.d/proxy.conf
[Service]
Environment="HTTP_PROXY=http://10.0.1.2:7890/"
Environment="HTTPS_PROXY=http://10.0.1.2:7890/"
Environment="NO_PROXY=127.0.0.1,localhost,192.168.*,*.example.com,10.*.*.*"
EOF
  fi

  sudo systemctl enable --now crond
fi

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
    git base-devel man man-db wget eza broot htop zsh docker docker-compose tmux bat duf \
    ncdu unzip fastfetch vim rsync nmap net-tools lsof dog httpie cronie fd sd p7zip rhash jq helix

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

# Termux
if hasCommand "termux-change-repo"; then
  # China mirror
  if [ "$CHINA_MAINLAND" != '0' ]; then
    section "Switching to pkg China mirror..."
    echo "deb https://mirrors.ustc.edu.cn/termux/apt/termux-main stable main" > $PREFIX/etc/apt/sources.list
  fi

  section "Installing basic packages..."
  pkg upgrade -y
  pkg install -y \
    nodejs-lts python-pip which tsu android-tools \
    git man wget eza broot htop zsh tmux neovim bat duf \
    ncdu unzip fastfetch vim rsync nmap net-tools lsof dog cronie fd sd p7zip rhash jq

  mkdir $HOME/.n # Skip tj/n and Node.js installation step
  pip install httpie

  if ! [ -d $HOME/storage ]; then
    section "Initializing storage..."
    termux-setup-storage
  fi

  section "Installing termux config..."
  mkdir -p $HOME/.termux
  curl https://$GITHUB_RAW/hjkcai/dotfiles/master/termux.properties > $HOME/.termux/termux.properties
  curl https://$GITHUB/googlefonts/Inconsolata/releases/download/v3.000/Inconsolata-VF.ttf > $HOME/.termux/font.ttf
  curl https://$GITHUB_RAW/termux/termux-styling/master/app/src/main/assets/colors/nord.properties > $HOME/.termux/colors.properties
  termux-reload-settings
fi

# Post-install check
if ! hasCommand "git"; then echo "Missing required command: git"; exit 1; fi
if ! hasCommand "zsh"; then echo "Missing required command: zsh"; exit 1; fi
if ! hasCommand "make"; then echo "Missing required command: make"; exit 1; fi

# Git
if ! [ -z "$GIT_NAME" ]; then
  section "Setting up Git..."
  git config --global user.name $GIT_NAME
  git config --global user.email $GIT_EMAIL
  git config --global pull.rebase 'false'
  git config --global credential.helper store
fi

# zsh
section "Changing default shell to zsh..."
if hasCommand "termux-change-repo"; then
  chsh -s zsh
else
  sudo chsh -s $(which zsh) $USER
fi

# oh-my-zsh
ZSH_CUSTOM=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
if ! [ -d $HOME/.oh-my-zsh ]; then
  section "Installing oh-my-zsh..."

  curl -fsSL https://$GITHUB_RAW/ohmyzsh/ohmyzsh/master/tools/install.sh > $PREFIX/tmp/oh-my-zsh
  if [ "$CHINA_MAINLAND" != '0' ]; then
    sed -i "s|github.com|$GITHUB|g" $PREFIX/tmp/oh-my-zsh
  fi
  RUNZSH=no CHSH=no bash $PREFIX/tmp/oh-my-zsh

  # agkozak zsh theme
  [[ ! -d $ZSH_CUSTOM/themes ]] && mkdir $ZSH_CUSTOM/themes
  git clone https://$GITHUB/agkozak/agkozak-zsh-prompt $ZSH_CUSTOM/themes/agkozak
  ln -s $ZSH_CUSTOM/themes/agkozak/agkozak-zsh-prompt.plugin.zsh $ZSH_CUSTOM/themes/agkozak.zsh-theme
  sed -i 's|/tmp/|$PREFIX/tmp/|g' $ZSH_CUSTOM/themes/agkozak.zsh-theme
fi

# zsh config
section "Installing zsh config..."
echo "CHINA_MAINLAND=${CHINA_MAINLAND:-1}" > $HOME/.zshrc
echo "" > $HOME/.zshrc
curl https://$GITHUB_RAW/hjkcai/dotfiles/master/zshrc >> $HOME/.zshrc

# oh-my-zsh plugins
section "Installing oh-my-zsh plugins..."
git clone https://$GITHUB/jeffreytse/zsh-vi-mode.git $ZSH_CUSTOM/plugins/zsh-vi-mode
git clone https://$GITHUB/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://$GITHUB/zdharma-continuum/fast-syntax-highlighting.git $ZSH_CUSTOM/plugins/fast-syntax-highlighting
git clone https://$GITHUB/unixorn/fzf-zsh-plugin.git $ZSH_CUSTOM/plugins/fzf-zsh-plugin
git clone https://$GITHUB/Aloxaf/fzf-tab.git $ZSH_CUSTOM/plugins/fzf-tab
git clone https://$GITHUB/agkozak/zsh-z.git $ZSH_CUSTOM/plugins/zsh-z
git clone https://$GITHUB/akarzim/zsh-docker-aliases.git $ZSH_CUSTOM/plugins/zsh-docker-aliases

# fzf
if ! hasCommand "fzf"; then
  section "Installing fzf..."
  git clone --depth 1 https://$GITHUB/junegunn/fzf.git $HOME/.fzf
  if [ "$CHINA_MAINLAND" != '0' ]; then
    sed -i "s|github.com|$GITHUB|g" $HOME/.fzf/install
  fi
  $HOME/.fzf/install --bin
fi

# broot
if hasCommand "broot"; then
  section "Installing broot..."
  zsh -c 'broot --install'
  curl https://$GITHUB_RAW/kreigor/broot-nord-theme/main/broot.skin > $HOME/.config/broot/nord.toml
  sed -i "s|dark-blue-skin.hjson|nord.toml|" $HOME/.config/broot/conf.hjson
fi

# tmux config
section "Installing tmux config..."
mkdir -p $HOME/.config/tmux
curl https://$GITHUB_RAW/hjkcai/dotfiles/master/tmux.conf > $HOME/.config/tmux/tmux.conf
if [ "$CHINA_MAINLAND" != '0' ]; then
  sed -i "s|https\://github.com|https\://$GITHUB|g" $HOME/.config/tmux/tmux.conf
fi
if ! [ -d $HOME/.tmux/plugins/tpm ]; then
  git clone https://$GITHUB/tmux-plugins/tpm $HOME/.tmux/plugins/tpm
fi
$HOME/.tmux/plugins/tpm/bin/install_plugins

# Helix config
section "Installing Helix config..."
mkdir -p $HOME/.config/helix
curl https://$GITHUB_RAW/hjkcai/dotfiles/master/helix.toml > $HOME/.config/helix/config.toml

# Node.js
if ! [ -d $HOME/.n ]; then
  section "Installing tj/n and Node.js..."
  export N_PREFIX=$HOME/.n
  curl -L https://$GITHUB_RAW/mklement0/n-install/stable/bin/n-install > /tmp/n-install

  if [ "$CHINA_MAINLAND" != '0' ]; then
    export N_NODE_MIRROR=https://mirrors.ustc.edu.cn/node/
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
npm install -g concurrently http-server npm-check-updates nodemon pm2 whistle yarn pnpm tldr tsx

section "Enjoy!"
fastfetch
