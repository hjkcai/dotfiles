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
  GITHUB=github.com
  GITHUB_RAW=raw.githubusercontent.com
else
  GITHUB=hub.fastgit.xyz
  GITHUB_RAW=raw.fastgit.org
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
  if [ "$CHINA_MAINLAND" != '0' ]; then
    section "Switching to pacman China mirror..."
    sudo reflector -l 5 -c China -p https --sort rate --save /etc/pacman.d/mirrorlist
  fi

  # Recommended packages
  section "Installing basic packages..."
  sudo pacman -Sy --noconfirm --needed \
    git base-devel man wget exa broot htop zsh docker docker-compose \
    ncdu unzip neofetch vim rsync nmap net-tools man-db lsof dog tldr httpie cronie

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
        sed -i 's/github.com/download.fastgit.org/g' PKGBUILD
      fi
      makepkg -si --noconfirm
    popd
  fi

  # ananicy
  if ! hasCommand "ananicy"; then
    section "Installing ananicy..."
    TEMP_DIR=`mktemp -u`
    git clone https://aur.archlinux.org/ananicy-git.git $TEMP_DIR
    pushd $TEMP_DIR
      if [ "$CHINA_MAINLAND" != '0' ]; then
        sed -i 's/git+https\:\/\/github.com/git+https\:\/\/hub.fastgit.xyz/' PKGBUILD
      fi
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
  curl -fsSL https://$GITHUB_RAW/ohmyzsh/ohmyzsh/master/tools/install.sh > /tmp/oh-my-zsh
  if [ "$CHINA_MAINLAND" != '0' ]; then
    sed -i 's/github.com/hub.fastgit.xyz/g' /tmp/oh-my-zsh
  fi
  RUNZSH=no bash /tmp/oh-my-zsh

  section "Installing oh-my-zsh plugins..."
  ZSH_CUSTOM=$HOME/.oh-my-zsh/custom
  git clone https://$GITHUB/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
  git clone https://$GITHUB/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions

  # agkozak zsh theme
  [[ ! -d $ZSH_CUSTOM/themes ]] && mkdir $ZSH_CUSTOM/themes
  git clone https://$GITHUB/agkozak/agkozak-zsh-prompt $ZSH_CUSTOM/themes/agkozak
  ln -s $ZSH_CUSTOM/themes/agkozak/agkozak-zsh-prompt.plugin.zsh $ZSH_CUSTOM/themes/agkozak.zsh-theme
fi

# zsh config
section "Installing zsh config..."
echo "CHINA_MAINLAND=${CHINA_MAINLAND:-1}\n" > $HOME/.zshrc
curl https://$GITHUB_RAW/hjkcai/dotfiles/master/zshrc >> $HOME/.zshrc

# Node.js
if ! [ -d $HOME/.n ]; then
  section "Installing tj/n and Node.js..."
  export N_PREFIX=$HOME/.n
  curl -L https://$GITHUB_RAW/mklement0/n-install/stable/bin/n-install > /tmp/n-install

  if [ "$CHINA_MAINLAND" != '0' ]; then
    export N_NODE_MIRROR=https://npm.taobao.org/mirrors/node
    sed -i 's/github.com/hub.fastgit.xyz/g' /tmp/n-install
    sed -i 's/raw.githubusercontent.com/raw.fastgit.org/g' /tmp/n-install
  fi

  bash /tmp/n-install -n -y latest

  if [ "$CHINA_MAINLAND" != '0' ]; then
    section "Setting npm registry..."
    $HOME/.n/npm config set registry ${NPM_REGISTRY:-https://registry.npm.taobao.org}
  fi
fi

# Node packages
section "Installing common Node.js packages..."
$HOME/.n/bin/npm install -g \
  concurrently create-react-app @feflow/cli http-server lerna \
  npm-check-updates nodemon pm2 ts-node typescript whistle yarn pnpm esno

section "Enjoy!"
neofetch
