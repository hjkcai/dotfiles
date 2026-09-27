# Exact versions for everything this config installs.
# Nix packages must match pkgs.<name>.version from the nixpkgs commit in flake.nix.
# Evaluation stops when they differ. After moving that commit, update the strings here.
# hunk is the version built from the hunk flake input.
# npm entries are exact registry versions. node is a major version passed to n, and only when node is absent.
{
  packages = {
    autorestic = "1.8.3";
    bat = "0.26.1";
    broot = "1.60.1";
    curl = "8.22.0";
    doggo = "1.4.0";
    duf = "0.9.1";
    eza = "0.23.5";
    fastfetch = "2.68.1";
    fd = "10.5.0";
    ffmpeg = "9.0.1";
    fzf = "0.74.4";
    git = "2.55.0";
    git-lfs = "3.7.1";
    helix = "25.07.1";
    herdr = "0.9.1";
    htop = "3.5.3";
    httpie = "3.2.4";
    jq = "1.8.2";
    lsof = "4.99.7";
    ncdu = "2.11.1";
    nmap = "7.991";
    p7zip = "17.06";
    pnpm = "12.3.4";
    redu = "0.2.15";
    restic = "0.18.1";
    rhash = "1.4.6";
    ripgrep = "15.2.0";
    rsync = "3.5.0";
    sd = "1.1.0";
    tealdeer = "1.9.0";
    tmux = "3.7c";
    unzip = "6.0";
    vim = "9.2.1001";
    viu = "1.6.1";
    wget = "1.25.0";
    which = "2.25";
    witr = "0.3.3";
    zip = "3.0";
    zsh = "5.9.2";
  };

  # Installed by programs.* rather than home.packages. Still checked above.
  programs = [
    "tmux"
    "zsh"
  ];

  n = "9.2.3";
  node = "24";

  # Built from the hunk flake input, not nixpkgs and not npm.
  hunk = "0.22.0";

  npm = {
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
}
