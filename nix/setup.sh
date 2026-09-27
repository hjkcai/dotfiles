#!/usr/bin/env bash
# Setup script for new machines
set -e

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
if ! hasCommand "curl" && ! hasCommand "wget"; then echo "Missing required command: curl or wget"; exit 1; fi

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
if [ -z "${GIT_NAME:-}" ] && hasCommand "git"; then
  GIT_NAME=`git config --global user.name || true`
fi
if [ -z "${GIT_EMAIL:-}" ] && hasCommand "git"; then
  GIT_EMAIL=`git config --global user.email || true`
fi
export GIT_NAME="${GIT_NAME:-}"
export GIT_EMAIL="${GIT_EMAIL:-}"

# Locale & Timezone
if hasCommand "locale-gen"; then
  section "Setting locale and timezone..."
  sudo bash -c "echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen"
  sudo locale-gen
  sudo localectl set-locale LANG=en_US.UTF-8
  sudo timedatectl set-timezone Asia/Shanghai
fi

# Nix
# 当前 shell 里没有 nix 就先装。/nix/var/nix/profiles 是安装器放命令的位置，不是 NixOS。
if ! hasCommand "nix" && [ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
if ! hasCommand "nix"; then
  section "Installing Nix..."
  if hasCommand "curl"; then
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm
  else
    wget -qO- https://install.determinate.systems/nix | sh -s -- install --no-confirm
  fi
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# 按 CHINA_MAINLAND 覆盖 /etc/nix/nix.conf 里的二进制缓存，并重启守护进程让它生效。
section "Setting up Nix..."
NIX_CONF=/etc/nix/nix.conf
BEGIN="# BEGIN dotfiles china mirror"
END="# END dotfiles china mirror"
TMP=`mktemp`
if [ -f $NIX_CONF ]; then
  awk -v b="$BEGIN" -v e="$END" '
    $0 == b { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' $NIX_CONF > $TMP
else
  : > $TMP
fi
if [ "$CHINA_MAINLAND" != '0' ]; then
  cat >> $TMP << EOF

$BEGIN
substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/
$END
EOF
fi
if [ -f $NIX_CONF ] || [ "$CHINA_MAINLAND" != '0' ]; then
  sudo mkdir -p /etc/nix
  sudo cp $TMP $NIX_CONF
fi
rm -f $TMP
if hasCommand "systemctl" && systemctl cat nix-daemon.service > /dev/null 2>&1; then
  sudo systemctl restart nix-daemon
fi

# Home Manager
# 覆盖 zsh、Helix、tmux 和命令行工具。原来的发行版包、oh-my-zsh、fzf、broot、Node.js 改由这一步安装。
section "Installing the Home Manager configuration..."
cd "$(dirname "$0")"
FLAKE_DIR=`pwd`
if [ "$CHINA_MAINLAND" != '0' ]; then
  STAGE=`mktemp -d`
  trap 'rm -rf "$STAGE"' EXIT
  cp -a flake.nix flake.lock home.nix versions.nix config "$STAGE/"
  sed -i "s|https://github.com/|https://$GITHUB/|g" "$STAGE/flake.nix" "$STAGE/flake.lock"
  FLAKE_DIR=$STAGE
fi
cd "$FLAKE_DIR"
system=`nix eval --impure --raw --expr 'builtins.currentSystem'`
nix run --impure ".#home-manager" -- switch --impure -b backup --flake ".#$system" "$@"
cd - > /dev/null
export PATH="$HOME/.nix-profile/bin:$PATH"

# Post-install check
if ! hasCommand "git"; then echo "Missing required command: git"; exit 1; fi
if ! hasCommand "zsh"; then echo "Missing required command: zsh"; exit 1; fi

# zsh
section "Changing default shell to zsh..."
ZSH_PATH=`which zsh`
if ! grep -qxF "$ZSH_PATH" /etc/shells; then
  echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
fi
if hasCommand "termux-change-repo"; then
  chsh -s zsh
else
  sudo chsh -s $ZSH_PATH $USER
fi

section "Enjoy!"
fastfetch
