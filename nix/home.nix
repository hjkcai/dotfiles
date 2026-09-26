{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  username = let
    fromEnv = builtins.getEnv "USER";
  in
    if fromEnv == "" then "user" else fromEnv;

  homeDirectory = let
    fromEnv = builtins.getEnv "HOME";
  in
    if fromEnv == "" then "/home/${username}" else fromEnv;

  # Same rule as setup.sh: only CHINA_MAINLAND=0 uses upstream.
  china = builtins.getEnv "CHINA_MAINLAND" != "0";
  gitName = builtins.getEnv "GIT_NAME";
  gitEmail = builtins.getEnv "GIT_EMAIL";
  n = pkgs.runCommand "n-9.2.3" { } ''
    mkdir -p $out/bin
    cp ${inputs.n}/bin/n $out/bin/n
    chmod +x $out/bin/n
  '';

  # npm specs passed through to `npm install`. Add @range to pin one later, for example "http-server@14".
  npmGlobals = [
    "@playwright/cli"
    "@rivolink/leaf"
    "concurrently"
    "http-server"
    "hunkdiff"
    "npm-check-updates"
    "pm2"
    "prettier"
    "source-map-explorer"
    "tsx"
    "typescript"
    "whistle"
  ];

  zshCustom = pkgs.linkFarm "oh-my-zsh-custom" [
    {
      name = "themes/agkozak.zsh-theme";
      path = "${inputs.agkozak-zsh-prompt}/agkozak-zsh-prompt.plugin.zsh";
    }
    {
      name = "plugins/zsh-vi-mode";
      path = inputs.zsh-vi-mode;
    }
    {
      name = "plugins/zsh-autosuggestions";
      path = inputs.zsh-autosuggestions;
    }
    {
      name = "plugins/fast-syntax-highlighting";
      path = inputs.fast-syntax-highlighting;
    }
    {
      name = "plugins/fzf-zsh-plugin";
      path = inputs.fzf-zsh-plugin;
    }
    {
      name = "plugins/fzf-tab";
      path = inputs.fzf-tab;
    }
    {
      name = "plugins/zsh-z";
      path = inputs.zsh-z;
    }
    {
      name = "plugins/zsh-docker-aliases";
      path = inputs.zsh-docker-aliases;
    }
  ];

  draculaNord = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "dracula-nord";
    version = inputs.dracula-nord.shortRev or "github";
    src = inputs.dracula-nord;
    rtpFilePath = "dracula.tmux";
  };
in
{
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "26.05";

  home.sessionPath = [
    "$HOME/.n/bin"
    "$HOME/.local/bin"
    "$HOME/.bin"
    "$HOME/.cargo/bin"
  ];
  home.sessionVariables.N_PREFIX = "${config.home.homeDirectory}/.n";

  home.packages = with pkgs; [
    bat
    broot
    curl
    doggo
    duf
    eza
    fastfetch
    fd
    fzf
    git
    git-lfs
    helix
    htop
    httpie
    jq
    lsof
    ncdu
    nmap
    p7zip
    pnpm
    rhash
    ripgrep
    rsync
    sd
    tealdeer
    unzip
    vim
    viu
    wget
    which
    witr
    zip
  ] ++ [ n ];

  programs.git = {
    enable = true;
    ignores = [ "**/.claude/settings.local.json" ];
    settings = {
      pull.rebase = false;
      credential.helper = "store";
    } // lib.optionalAttrs (gitName != "" || gitEmail != "") {
      user = lib.filterAttrs (_: value: value != "") {
        name = gitName;
        email = gitEmail;
      };
    };
  };

  # Git reads ~/.gitconfig over ~/.config/git/config, so the generated file has to live here.
  xdg.configFile."git/config".enable = lib.mkForce false;
  home.file.".gitconfig".text = config.xdg.configFile."git/config".text;

  programs.bat = {
    enable = true;
    config.theme = "Nord";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = false;
  };

  programs.helix = {
    enable = true;
    settings = {
      theme = "nord";
      editor = {
        bufferline = "multiple";
        cursorline = true;
        true-color = true;
        color-modes = true;
        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };
      };
      keys.normal.esc = [
        "collapse_selection"
        "keep_primary_selection"
      ];
    };
  };

  programs.tmux = {
    enable = true;
    prefix = "C-a";
    mouse = true;
    baseIndex = 1;
    historyLimit = 20000;
    aggressiveResize = false;
    terminal = "tmux-256color";
    shell = "${pkgs.zsh}/bin/zsh";
    sensibleOnTop = true;
    extraConfig = ''
      bind-key C-a last-window
      bind-key a send-prefix
      set -sa terminal-overrides ",*256*:Tc"
      set -g allow-passthrough on
    '';
    plugins = [
      pkgs.tmuxPlugins.better-mouse-mode
      {
        plugin = draculaNord;
        extraConfig = ''
          set -g @dracula-show-left-icon session
        '';
      }
    ];
  };

  xdg.configFile."nix/nix.conf" = lib.mkIf china {
    text = ''
      substituters = https://mirrors.ustc.edu.cn/nix-channels/store https://cache.nixos.org/
    '';
  };

  home.file.".cargo/config.toml" = lib.mkIf china {
    text = ''
      [source.crates-io]
      replace-with = "ustc"

      [source.ustc]
      registry = "sparse+https://mirrors.ustc.edu.cn/crates.io-index/"
    '';
  };

  xdg.configFile."broot/nord.toml".source = "${inputs.broot-nord}/broot.skin";
  xdg.configFile."broot/conf.hjson".text = ''
    imports: [
      {
        luma: [
          dark
          unknown
        ]
        file: nord.toml
      }
    ]
  '';

  programs.zsh = {
    enable = true;
    setOptions = [ "HIST_IGNORE_SPACE" ];
    oh-my-zsh = {
      enable = true;
      theme = "agkozak";
      custom = "${zshCustom}";
      plugins = [
        "git"
        "sudo"
        "node"
        "npm"
        "macos"
        "extract"
        "zsh-vi-mode"
        "fast-syntax-highlighting"
        "zsh-autosuggestions"
        "fzf-tab"
        "zsh-z"
        "zsh-docker-aliases"
      ];
    };
    initContent = lib.mkMerge [
      (lib.mkBefore ''
        if [ -f "$HOME/.zshrc-private" ]; then
          source "$HOME/.zshrc-private"
        fi

        if [ "$CHINA_MAINLAND" != '0' ]; then
          export GITHUB=ghfast.top/https://github.com
          export GITHUB_RAW=ghfast.top/https://raw.githubusercontent.com
          export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com/
          export N_NODE_MIRROR=https://mirrors.ustc.edu.cn/node/
        else
          export GITHUB=github.com
          export GITHUB_RAW=raw.githubusercontent.com
        fi

        function zvm_config() {
          ZVM_READKEY_ENGINE=$ZVM_READKEY_ENGINE_ZLE
          ZVM_KEYTIMEOUT=0.2
          ZVM_ESCAPE_KEYTIMEOUT=0.2
        }

        function zvm_after_init() {
          bindkey -v '^[[A' up-line-or-beginning-search
          bindkey -v '^[[B' down-line-or-beginning-search
          source $ZSH_CUSTOM/plugins/fzf-zsh-plugin/fzf-zsh-plugin.plugin.zsh
          export FZF_DEFAULT_OPTS=$FZF_DEFAULT_OPTS'
            --color fg:#D8DEE9,bg:#2E3440,hl:#A3BE8C,fg+:#D8DEE9,bg+:#434C5E,hl+:#A3BE8C
            --color pointer:#BF616A,info:#4C566A,spinner:#4C566A,header:#4C566A,prompt:#81A1C1,marker:#EBCB8B'
        }
      '')
      (lib.mkAfter ''
        AGKOZAK_CUSTOM_PROMPT=$'%(!.%S%B.%B%F{green})%n%1v%(!.%b%s.%f%b) '
        AGKOZAK_CUSTOM_PROMPT+='%B%F{blue}%2v%f%b'
        AGKOZAK_CUSTOM_PROMPT+=$'%(3V.%F{243}%3v%f.)\n'
        AGKOZAK_CUSTOM_PROMPT+='%(4V.:.%(!.#.$)) '
        AGKOZAK_CUSTOM_RPROMPT=$'%{\e[1A%}%(?..%B%F{red}(%?%)%f%b )%F{243}%*%f%{\e[1B%}'
        AGKOZAK_PROMPT_DIRTRIM=4
        AGKOZAK_BLANK_LINES=1
        AGKOZAK_CUSTOM_SYMBOLS=( '↓↑' '↓' '↑' '+' 'x' '*' '>' '?' 'S')
        AGKOZAK_FORCE_ASYNC_METHOD=none

        export BAT_THEME=Nord
        alias cat="bat -pp"

        if command -v broot > /dev/null; then
          eval "$(broot --print-shell-function zsh)"
        fi

        if [ -f "$HOME/.cargo/env" ]; then
          . "$HOME/.cargo/env"
        fi

        alias zl="z -l"
        alias zc="z -c"

        alias ls="eza"
        alias l="eza -lF --time-style=long-iso"
        alias la="eza -lF --time-style=long-iso -a"
        alias ll="eza -lhF --time-style=long-iso --git"
        alias lla="eza -lhF --time-style=long-iso --git -a"
        alias laa="eza -lhHigUmuSa --time-style=long-iso --git --color-scale"
        alias tree="eza --tree --level=2"

        alias npmc="npm --registry=https://registry.npmmirror.com"
        alias ni="npm i"
        alias nid="npm i -D"
        alias nig="npm i -g"
        alias nr="npm run"
        alias np="npm publish"
        alias nu="npm uninstall"
        alias nrb="npm run build"
        alias nrd="npm run dev"
        alias nrl="npm run lint"
        alias nrlf="npm run lint -- --fix"
        alias nrt="npm run test"
        alias nrtc="npm run test -- --coverage"
        alias nrtw="npm run test -- --watch"
        alias pi="pnpm i"
        alias pid="pnpm i -D"
        alias pig="pnpm i -g"
        alias piw="pnpm i -w"
        alias piwd="pnpm i -w -D"

        npm-link() {
          module="./node_modules/$1"
          rm -r "$module"
          ln -s "$2" "$module"
        }

        alias tscp="tsc -p ."
        alias tscpw="tsc -p . -w"
        alias tscpp="tsc -p tsconfig.prod.json"
        alias tscppw="tsc -p tsconfig.prod.json -w"
        alias jest="npx jest"
        alias jestb="npx jest --runInBand"
        alias jestc="npx jest --coverage"
        alias jestp="npx jest --testPathPattern"
        alias jestbp="npx jest --runInBand --testPathPattern"

        alias adb-scr="adb exec-out screencap -p"
        alias adb-scrcpy="adb exec-out screencap -p | impbcopy -"
        alias adb-deeplink="adb shell am start -W -a android.intent.action.VIEW -d"
        alias adb-paste="adb shell am broadcast -a clipper.get"
        alias adb-copy="adb shell am broadcast -a clipper.set -e text"
        alias adb-kill="adb shell am force-stop"

        if command -v hx > /dev/null; then
          export EDITOR="hx"
          export VISUAL="hx"
        elif command -v helix > /dev/null; then
          export EDITOR="helix"
          export VISUAL="helix"
          alias hx="helix"
        fi

        alias dkcdu="docker-compose down && docker-compose up"
        alias dkcdU="docker-compose down && docker-compose up -d"
        alias dkclf="docker-compose logs -f --tail 100"

        if command -v stack > /dev/null; then
          alias sr="stack run"
          alias sb="stack build"
          alias srs="stack run --silent"
          alias sghci="stack ghci"
        fi

        if command -v flutter > /dev/null; then
          export PUB_HOSTED_URL=https://pub.flutter-io.cn
          export FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
        fi

        alias unset-proxy="unset http_proxy && unset https_proxy"
        alias ioa-proxy="export http_proxy=http://127.0.0.1:12639 && export https_proxy=http://127.0.0.1:12639"
        alias ss-proxy="export http_proxy=http://127.0.0.1:1080 && export https_proxy=http://127.0.0.1:1080"
        alias clash-proxy="export http_proxy=http://127.0.0.1:7890 && export https_proxy=http://127.0.0.1:7890"

        alias ports-usage="lsof -i -P -sTCP:LISTEN"
        alias hs="http-server"
        alias sudo="sudo "
        alias env="/usr/bin/env -0 | sort -z | tr '\0' '\n' | sd '(^|\n)([A-Za-z0-9_]+)=' \$(printf '\$1\033[1;32m\$2\033[0m=')"

        tm() {
          tmux new-session -A -s ''${1:-main}
        }

        clear-scrollback-and-screen() {
          echo -n -e '\e[2J\e[3J\e[1;1H'
          zle clear-screen
          tmux clear-history 2>/dev/null || true
        }
        zle -N clear-scrollback-and-screen
        bindkey -v '^L' clear-scrollback-and-screen
      '')
    ];
  };

  # Node itself is installed by tj/n into $N_PREFIX. This only downloads a version when none is present.
  home.activation.npmGlobals = lib.hm.dag.entryAfter [ "installPackages" ] ''
    export N_PREFIX="$HOME/.n"
    export PATH="$N_PREFIX/bin:${lib.makeBinPath [
      n
      pkgs.curl
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.coreutils
      pkgs.gnutar
      pkgs.xz
    ]}:$PATH"
    if [ "''${CHINA_MAINLAND:-}" != 0 ]; then
      export N_NODE_MIRROR=https://mirrors.ustc.edu.cn/node/
      export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com/
    fi
    if ! command -v node >/dev/null 2>&1; then
      n lts
    fi
    npm install --global --prefix "$HOME/.local" ${lib.escapeShellArgs npmGlobals}
  '';
}
