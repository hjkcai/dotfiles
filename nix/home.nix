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
  versions = import ./versions.nix;

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

  # pkgs.<name> from the locked nixpkgs must be this exact version.
  pin = name:
    let
      pkg = pkgs.${name};
      want = versions.packages.${name};
    in
    if pkg.version != want then
      throw ''
        ${name} from nixpkgs is ${pkg.version}, but versions.nix pins ${want}.
        Update versions.nix after changing the nixpkgs commit in flake.nix.
      ''
    else
      pkg;

  n = pkgs.runCommand "n-${versions.n}" { } ''
    mkdir -p $out/bin
    cp ${inputs.n}/bin/n $out/bin/n
    chmod +x $out/bin/n
  '';

  hunkPackage = inputs.hunk.packages.${pkgs.stdenv.hostPlatform.system}.hunk;

  npmGlobals = lib.mapAttrsToList (name: version: "${name}@${version}") versions.npm;

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

  home.packages =
    map pin (lib.filter (name: !builtins.elem name versions.programs) (builtins.attrNames versions.packages))
    ++ [ n ];

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
    package = pin "tmux";
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

  xdg.configFile."broot/nord.toml".source = "${inputs.broot-nord}/broot.skin";
  xdg.configFile."broot/conf.hjson".source = ./config/broot.hjson;

  xdg.configFile."herdr/config.toml".source = ./config/herdr.toml;
  xdg.configFile."herdr-automatic-rename/config.sh".source = ./config/herdr-automatic-rename.sh;
  # plugins.json stays a normal file. Herdr rewrites it when the registry changes,
  # and a symlink into the Nix store cannot be updated.
  xdg.configFile.${herdrAutomaticRenameCheckout}.source = herdrAutomaticRename;

  xdg.configFile."leaf/config.toml".source = ./config/leaf.toml;
  xdg.configFile."leaf/nord.toml".source = ./config/leaf-nord.toml;

  programs.hunk = {
    enable = true;
    package =
      if hunkPackage.version != versions.hunk then
        throw ''
          hunk from the flake input is ${hunkPackage.version}, but versions.nix pins ${versions.hunk}.
          Update versions.nix after changing the hunk commit in flake.nix.
        ''
      else
        hunkPackage;
    settings = builtins.fromTOML (builtins.readFile ./config/hunk.toml);
  };

  programs.zsh = {
    enable = true;
    package = pin "zsh";
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
    list="$(${pin "herdr"}/bin/herdr plugin list --json)"
    root="$(printf '%s\n' "$list" | ${pin "jq"}/bin/jq -r --arg id ${lib.escapeShellArg herdrAutomaticRenameId} '.result.plugins[] | select(.plugin_id==$id) | .plugin_root')"
    if [ "$root" != "$checkout" ]; then
      ${pin "herdr"}/bin/herdr plugin link "$checkout" >/dev/null
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
      n ${versions.node}
    fi
    npm install --global --prefix "$HOME/.local" ${lib.escapeShellArgs npmGlobals}
  '';
}
