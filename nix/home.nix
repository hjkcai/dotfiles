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

  nodeVersion = "24";

  # herdr and broot share nixpkgs-unstable. nixos-26.05 has no herdr.
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  herdr = unstable.herdr;
  broot = unstable.broot;

  # Oh My Zsh is inserted at this line. The two sides stay in source order.
  zshrcParts =
    let
      parts = lib.splitString "# {{HOME_MANAGER}}\n" (builtins.readFile ./config/zshrc.zsh);
    in
    if builtins.length parts == 2 then
      parts
    else
      throw "config/zshrc.zsh must contain exactly one \"# {{HOME_MANAGER}}\" line";
  zshrcBefore = builtins.elemAt zshrcParts 0;
  zshrcAfter = builtins.elemAt zshrcParts 1;

  n = pkgs.runCommand "n" { } ''
    mkdir -p $out/bin
    cp ${inputs.n}/bin/n $out/bin/n
    chmod +x $out/bin/n
  '';

  hunkPackage = inputs.hunk.packages.${pkgs.stdenv.hostPlatform.system}.hunk;

  npmGlobals = lib.mapAttrsToList (name: version: "${name}@${version}") {
    "@playwright/cli" = "0.1.21";
    "@rivolink/leaf" = "1.28.2";
    concurrently = "10.0.5";
    http-server = "14.1.1";
    npm-check-updates = "23.1.0";
    pm2 = "7.0.4";
    prettier = "3.9.9";
    source-map-explorer = "2.5.3";
    tsx = "4.23.15";
    typescript = "7.0.2";
    whistle = "2.10.10";
  };

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

  # Same directory name as `herdr plugin install`: slug plus the first 6 bytes
  # of sha256(plugin id), hex. See plugin_managed_path_component in herdr 0.9.5.
  herdrAutomaticRename = inputs.herdr-automatic-rename;
  herdrAutomaticRenameManifest = builtins.fromTOML (
    builtins.readFile "${herdrAutomaticRename}/herdr-plugin.toml"
  );
  herdrAutomaticRenameId = herdrAutomaticRenameManifest.id;
  herdrAutomaticRenameCheckout = "herdr/plugins/github/${herdrAutomaticRenameId}-${
    builtins.substring 0 12 (builtins.hashString "sha256" herdrAutomaticRenameId)
  }";

  draculaNord = pkgs.tmuxPlugins.mkTmuxPlugin {
    pluginName = "dracula-nord";
    version = inputs.dracula-nord.shortRev or "github";
    src = inputs.dracula-nord;
    rtpFilePath = "dracula.tmux";
  };
in
{
  imports = [
    inputs.hunk.homeManagerModules.default
    ./agent
  ];

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
    android-tools
    aria2
    autorestic
    broot
    curl
    doggo
    duf
    eza
    fastfetch
    fd
    ffmpeg
    # The package only. ~/.gitconfig is written once by setup.sh, so a later
    # switch cannot drop safe.directory or url.insteadOf.
    git
    git-lfs
    # CLI and pam_google_authenticator.so. The TOTP secret stays on the machine.
    google-authenticator
    herdr
    htop
    jq
    lsof
    n
    ncdu
    nmap
    p7zip
    redu
    restic
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
    xh
    zip
  ];

  programs.bat = {
    enable = true;
    config.theme = "Nord";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.helix.enable = true;
  xdg.configFile."helix/config.toml".source = ./config/helix.toml;

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
    extraConfig = builtins.readFile ./config/tmux.conf;
    plugins = [
      pkgs.tmuxPlugins.better-mouse-mode
      {
        plugin = draculaNord;
        extraConfig = builtins.readFile ./config/tmux-dracula.conf;
      }
    ];
  };

  home.file.".cargo/config.toml" = lib.mkIf china {
    source = ./config/cargo.toml;
  };

  xdg.configFile."broot/nord.toml".source = ./config/broot-nord.toml;
  xdg.configFile."broot/conf.toml".source = ./config/broot.toml;

  xdg.configFile."herdr/config.toml".source = ./config/herdr.toml;
  xdg.configFile."herdr-automatic-rename/config.sh".source = ./config/herdr-automatic-rename.sh;
  # plugins.json stays a normal file. Herdr rewrites it when the registry changes,
  # and a symlink into the Nix store cannot be updated.
  xdg.configFile.${herdrAutomaticRenameCheckout}.source = herdrAutomaticRename;

  xdg.configFile."leaf/config.toml".source = ./config/leaf.toml;
  xdg.configFile."leaf/nord.toml".source = ./config/leaf-nord.toml;

  xdg.configFile."opencode/cli.json".source = ./config/opencode-cli.json;
  xdg.configFile."opencode/themes/my-nord.json".source = ./config/opencode-my-nord.json;

  # cli-config.json and mcp.json stay real files. Cursor rewrites both.
  home.file.".cursor/hooks.json".source = ./config/cursor/hooks.json;
  home.file.".cursor/hooks/agents-md-context.sh".source = ./config/cursor/hooks/agents-md-context.sh;
  home.file.".cursor/osc52-fix/wl-copy".source = ./config/cursor/osc52-fix/wl-copy;

  programs.hunk = {
    enable = true;
    package = hunkPackage;
    settings = builtins.fromTOML (builtins.readFile ./config/hunk.toml);
  };

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
      (lib.mkBefore zshrcBefore)
      (lib.mkAfter zshrcAfter)
    ];
  };

  # `plugin install` would git-clone a second copy and refuse to replace this
  # checkout. Link registers the stable symlink, not the store path: the store
  # path changes on the next update, and plugins.json is not managed by Nix.
  # Skip when that entry already points here, so a disabled plugin is not turned
  # back on at every setup. Runs after the symlink exists.
  home.activation.linkHerdrAutomaticRename = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    stable=${lib.escapeShellArg "${config.xdg.configHome}/${herdrAutomaticRenameCheckout}"}
    # A running older server refuses the new client. Stopping it would exit
    # every pane, so leave plugins.json alone until the user restarts Herdr.
    # The managed checkout is already symlinked at $stable, which is the path
    # an existing registration uses.
    list="$(${herdr}/bin/herdr plugin list --json 2>&1 || true)"
    if printf '%s\n' "$list" | ${pkgs.gnugrep}/bin/grep -q protocol_mismatch; then
      echo "herdr server is older than this client; plugin link skipped until herdr restarts" >&2
    else
      root="$(printf '%s\n' "$list" | ${pkgs.jq}/bin/jq -r --arg id ${lib.escapeShellArg herdrAutomaticRenameId} '.result.plugins[] | select(.plugin_id==$id) | .plugin_root')"
      root_real=""
      if [ -n "$root" ] && [ "$root" != "null" ]; then
        root_real="$(${pkgs.coreutils}/bin/realpath "$root" 2>/dev/null || true)"
      fi
      stable_real="$(${pkgs.coreutils}/bin/realpath "$stable")"
      if [ "$root_real" != "$stable_real" ]; then
        link_out="$(${herdr}/bin/herdr plugin link "$stable" 2>&1)" || {
          if printf '%s\n' "$link_out" | ${pkgs.gnugrep}/bin/grep -q protocol_mismatch; then
            echo "herdr server is older than this client; plugin link skipped until herdr restarts" >&2
          else
            printf '%s\n' "$link_out" >&2
            exit 1
          fi
        }
      fi
    fi
  '';

  # Node itself is installed by tj/n into $N_PREFIX. This only downloads a version when none is present.
  # Globals land in that same prefix, so they replace the bins already on PATH.
  # An existing registry (for example a company mirror in ~/.npmrc) is kept.
  # npmmirror is used only for the default registry.npmjs.org, and only in China mode.
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
      registry="$(npm config get registry 2>/dev/null || true)"
      case "$registry" in
        https://registry.npmjs.org|https://registry.npmjs.org/)
          export NPM_CONFIG_REGISTRY=https://registry.npmmirror.com/
          ;;
      esac
    fi
    if ! command -v node >/dev/null 2>&1; then
      n ${nodeVersion}
    fi
    npm install --global --prefix "$N_PREFIX" ${lib.escapeShellArgs npmGlobals}
  '';
}
