# Setup script for new machines
function section {
  echo
  echo -e "\033[0;31m${1}\033[0m"
}

function hasCommand {
  type $1 > /dev/null 2>&1
  return $?
}

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
echo -n 'Email: '
read GIT_EMAIL

# Locale & Timezone
section "Setting locale and timezone..."
sudo bash -c "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen"
sudo locale-gen
sudo localectl set-locale LANG=en_US.UTF-8
sudo timedatectl set-timezone Asia/Shanghai

# Arch Linux
if hasCommand "pacman"; then
  # China mirror
  section "Switching to pacman China mirror..."
  sudo reflector -l 5 -c China -p https --sort rate --save /etc/pacman.d/mirrorlist

  # Recommended packages
  section "Installing basic packages..."
  sudo pacman -Sy --noconfirm --needed \
    git base-devel man wget exa broot htop zsh docker docker-compose \
    ncdu unzip neofetch vim rsync nmap net-tools man-db lsof

  # Docker
  section "Enabling Docker..."
  sudo mkdir -p /etc/docker
  sudo bash -c "echo '{\"registry-mirrors\": [\"https://docker.mirrors.ustc.edu.cn/\"]}' > /etc/docker/daemon.json"
  sudo systemctl enable docker
  sudo systemctl start docker

  # yay
  if ! hasCommand "yay"; then
    section "Installing yay..."
    TEMP_DIR=`mktemp -u`
    git clone https://aur.archlinux.org/yay-bin.git $TEMP_DIR
    pushd $TEMP_DIR
      sed -i 's/github.com/download.fastgit.org/g' PKGBUILD
      makepkg -si --noconfirm
    popd
  fi

  # ananicy
  if ! hasCommand "ananicy"; then
    section "Installing ananicy..."
    TEMP_DIR=`mktemp -u`
    git clone https://aur.archlinux.org/ananicy-git.git $TEMP_DIR
    pushd $TEMP_DIR
      sed -i 's/git+https\:\/\/github.com/git+https\:\/\/hub.fastgit.xyz/' PKGBUILD
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
if ! [ -d $HOME/.oh-my-zsh ]; then
  section "Installing oh-my-zsh..."
  sudo chsh -s /usr/bin/zsh $USER
  curl -fsSL https://raw.fastgit.org/ohmyzsh/ohmyzsh/master/tools/install.sh > /tmp/oh-my-zsh
  sed -i 's/github.com/hub.fastgit.xyz/g' /tmp/oh-my-zsh
  RUNZSH=no bash /tmp/oh-my-zsh

  section "Installing oh-my-zsh plugins..."
  ZSH_CUSTOM=$HOME/.oh-my-zsh/custom
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
if ! [ -d $HOME/.n ]; then
  section "Installing tj/n and Node.js..."
  export N_NODE_MIRROR=https://npm.taobao.org/mirrors/node
  export N_PREFIX=$HOME/.n
  curl -L https://raw.fastgit.org/mklement0/n-install/stable/bin/n-install > /tmp/n-install
  sed -i 's/github.com/hub.fastgit.xyz/g' /tmp/n-install
  sed -i 's/raw.githubusercontent.com/raw.fastgit.org/g' /tmp/n-install
  bash /tmp/n-install -n -y latest

  section "Setting npm registry..."
  $HOME/.n/npm config set registry ${NPM_REGISTRY:-https://registry.npm.taobao.org}
fi

# Node packages
section "Installing common Node.js packages..."
$HOME/.n/bin/npm install -g \
  concurrently create-react-app @feflow/cli http-server lerna \
  npm-check-update nodemon pm2 ts-node typescript whistle yarn

section "Enjoy!"
neofetch
