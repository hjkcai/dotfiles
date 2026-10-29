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

# -y skips the hostname and Git prompts. An empty Git answer keeps the name and email already on this machine.
YES=0
PASS=()
for arg in "$@"; do
  if [ "$arg" = "-y" ]; then
    YES=1
  else
    PASS+=("$arg")
  fi
done
set -- "${PASS[@]}"

# Hostname
section "Please enter your new HOSTNAME (Currently '$HOSTNAME'). Leave it empty to skip."
echo -n "HOSTNAME: "
if [ "$YES" = 1 ]; then
  echo
  NEW_HOSTNAME=
else
  read NEW_HOSTNAME
fi
if ! [ -z "$NEW_HOSTNAME" ]; then
  sudo hostnamectl set-hostname $NEW_HOSTNAME
fi

# Git identity is applied after git exists. An empty answer leaves ~/.gitconfig
# untouched. Home Manager does not own that file.
GIT_NAME_SET=0
section "Please enter your default Git information. Leave it empty to keep the current name and email."
echo -n 'Username: '
if [ "$YES" = 1 ]; then
  echo
  GIT_NAME=
else
  read GIT_NAME
fi
if ! [ -z "$GIT_NAME" ]; then
  GIT_NAME_SET=1
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

# Determinate Nix 会覆盖 /etc/nix/nix.conf，用户设置要写在它 !include 的 nix.custom.conf。
# 写 substituters 而不是 extra-substituters，镜像才会排在 cache.nixos.org 前面。
section "Setting up Nix..."
NIX_CONF=/etc/nix/nix.custom.conf
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

# broot ignores conf.toml while conf.hjson exists. Keep the old file beside it.
if [ -f "$HOME/.config/broot/conf.hjson" ]; then
  mv "$HOME/.config/broot/conf.hjson" "$HOME/.config/broot/conf.hjson.backup"
fi

# These bins would shadow the Nix packages. Keep them under a sibling name.
move_aside() {
  if [ -e "$1" ] || [ -L "$1" ]; then
    if [ ! -e "$1.before-nix" ] && [ ! -L "$1.before-nix" ]; then
      mv "$1" "$1.before-nix"
    fi
  fi
}
move_aside "$HOME/.local/bin/herdr"
move_aside "$HOME/.n/bin/hunk"
move_aside "$HOME/.n/bin/hunkdiff"

# Home Manager
# 覆盖 zsh、Helix、tmux 和命令行工具。原来的发行版包、oh-my-zsh、fzf、broot、Node.js 改由这一步安装。
section "Installing the Home Manager configuration..."
cd "$(dirname "$0")"
FLAKE_DIR=`pwd`
if [ "$CHINA_MAINLAND" != '0' ]; then
  STAGE=`mktemp -d`
  trap 'rm -rf "$STAGE"' EXIT
  cp -a flake.nix flake.lock home.nix config agent "$STAGE/"
  sed -i "s|https://github.com/|https://$GITHUB/|g" "$STAGE/flake.nix" "$STAGE/flake.lock"
  FLAKE_DIR=$STAGE
fi
cd "$FLAKE_DIR"
system=`nix eval --impure --raw --expr 'builtins.currentSystem'`
nix run --impure ".#home-manager" -- switch --impure -b backup --flake ".#$system" "$@"
cd - > /dev/null
export PATH="$HOME/.local/state/nix/profiles/home-manager/bin:$HOME/.nix-profile/bin:$PATH"

# Post-install check
if ! hasCommand "git"; then echo "Missing required command: git"; exit 1; fi
if ! hasCommand "zsh"; then echo "Missing required command: zsh"; exit 1; fi

# Write ~/.gitconfig once. A later setup must not replace safe.directory or
# url.insteadOf. A name typed at the prompt still updates those two keys.
if [ ! -e "$HOME/.gitconfig" ]; then
  section "Writing Git config..."
  mkdir -p "$HOME/.config/git"
  printf '%s\n' '**/.claude/settings.local.json' > "$HOME/.config/git/ignore"
  git config --global core.excludesFile "$HOME/.config/git/ignore"
  git config --global pull.rebase false
  git config --global credential.helper store
fi
if [ "$GIT_NAME_SET" = 1 ]; then
  git config --global user.name "$GIT_NAME"
  if [ -n "${GIT_EMAIL:-}" ]; then
    git config --global user.email "$GIT_EMAIL"
  fi
fi

# zsh
# /usr/bin/zsh reads the Home Manager ~/.zshrc. A /nix/store path changes on
# upgrade, so it must not become the login shell.
section "Changing default shell to zsh..."
if [ -x /usr/bin/zsh ]; then
  ZSH_PATH=/usr/bin/zsh
else
  ZSH_PATH=`which zsh`
fi
case "$ZSH_PATH" in
  /nix/store/*)
    echo "Leaving the login shell unchanged. $ZSH_PATH changes when Nix updates."
    ;;
  *)
    if ! grep -qxF "$ZSH_PATH" /etc/shells; then
      echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi
    if hasCommand "termux-change-repo"; then
      chsh -s zsh
    else
      sudo chsh -s $ZSH_PATH $USER
    fi
    ;;
esac

section "Enjoy!"
fastfetch
