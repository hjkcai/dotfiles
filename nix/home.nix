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
  nodeVersion = "24";

  # herdr is not in the main nixos-26.05 snapshot.
  herdr = inputs.nixpkgs-herdr.legacyPackages.${pkgs.stdenv.hostPlatform.system}.herdr;

  # broot tracks nixpkgs-unstable. Everything else stays on nixos-26.05.
  broot = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.broot;

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
  # of sha256(plugin id), hex. See plugin_managed_path_component in herdr 0.9.1.
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
    autorestic
    broot
    curl
    doggo
    duf
    eza
    fastfetch
    fd
    ffmpeg
    git-lfs
    # CLI and pam_google_authenticator.so. The TOTP secret stays on the machine.
    google-authenticator
    herdr
    htop
    httpie
    jq
    lsof
    n
    ncdu
    nmap
    p7zip
    pnpm
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
    zip
  ];

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
  # checkout. Link registers the pinned tree in plugins.json, including when
  # the Herdr server is already running. Skip when that entry already points here,
  # so a disabled plugin is not turned back on at every setup.
  home.activation.linkHerdrAutomaticRename = lib.hm.dag.entryAfter [ "installPackages" ] ''
    checkout=${lib.escapeShellArg herdrAutomaticRename}
    list="$(${herdr}/bin/herdr plugin list --json)"
    root="$(printf '%s\n' "$list" | ${pkgs.jq}/bin/jq -r --arg id ${lib.escapeShellArg herdrAutomaticRenameId} '.result.plugins[] | select(.plugin_id==$id) | .plugin_root')"
    if [ "$root" != "$checkout" ]; then
      ${herdr}/bin/herdr plugin link "$checkout" >/dev/null
    fi
  '';

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
      n ${nodeVersion}
    fi
    npm install --global --prefix "$HOME/.local" ${lib.escapeShellArgs npmGlobals}
  '';
}
