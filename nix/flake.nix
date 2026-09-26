{
  description = "Home Manager config for Linux, any username";

  nixConfig = {
    extra-experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  inputs = {
    # These GitHub archive URLs are the canonical bytes recorded in flake.lock.
    # setup.sh fetches them through ghfast.top when CHINA_MAINLAND is not 0.
    nixpkgs.url = "https://github.com/NixOS/nixpkgs/archive/4975466d324710c576dc11ad614684e6bd8cad8e.tar.gz";
    home-manager = {
      url = "https://github.com/nix-community/home-manager/archive/4b9add8645d5e2b0f7de18f7a442d08fe2bdcc91.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    agkozak-zsh-prompt = {
      url = "https://github.com/agkozak/agkozak-zsh-prompt/archive/2055c42a6e2f5bdc6e8dc4b453b0084ced3f471a.tar.gz";
      flake = false;
    };
    zsh-vi-mode = {
      url = "https://github.com/jeffreytse/zsh-vi-mode/archive/91cafe4a09b6670cb8e761aa413e5f7b9e00816f.tar.gz";
      flake = false;
    };
    zsh-autosuggestions = {
      url = "https://github.com/zsh-users/zsh-autosuggestions/archive/85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5.tar.gz";
      flake = false;
    };
    fast-syntax-highlighting = {
      url = "https://github.com/zdharma-continuum/fast-syntax-highlighting/archive/4672ad5dd9ad68a7effc1476d65afb7c584ce2b3.tar.gz";
      flake = false;
    };
    fzf-zsh-plugin = {
      url = "https://github.com/unixorn/fzf-zsh-plugin/archive/e3894e83a3e8a3e8751456d56c51bb49b34e8d2b.tar.gz";
      flake = false;
    };
    fzf-tab = {
      url = "https://github.com/Aloxaf/fzf-tab/archive/24105b15714bfec37989ed5c5b6e60f572253019.tar.gz";
      flake = false;
    };
    zsh-z = {
      url = "https://github.com/agkozak/zsh-z/archive/102fb78036ed76feedf623907483691777a1d510.tar.gz";
      flake = false;
    };
    zsh-docker-aliases = {
      url = "https://github.com/akarzim/zsh-docker-aliases/archive/77716803ac38ed0ab414c71ff25c8f9565ec2849.tar.gz";
      flake = false;
    };
    dracula-nord = {
      url = "https://github.com/hjkcai/dracula-nord/archive/636c199a1461df66237e55918dfe43c4537e6860.tar.gz";
      flake = false;
    };
    broot-nord = {
      url = "https://github.com/kreigor/broot-nord-theme/archive/a4315f0e82e892227b0da0f3228128f809a48243.tar.gz";
      flake = false;
    };
    # nixpkgs has no tj/n package. Pin the upstream script instead.
    n = {
      url = "https://github.com/tj/n/archive/371affba8a21ec95ca1cab784ef409c879e6ce83.tar.gz";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    in
    {
      homeConfigurations = builtins.listToAttrs (
        map (system: {
          name = system;
          value = home-manager.lib.homeManagerConfiguration {
            pkgs = nixpkgs.legacyPackages.${system};
            extraSpecialArgs = {
              inherit inputs;
            };
            modules = [ ./home.nix ];
          };
        }) systems
      );

      packages = builtins.listToAttrs (
        map (system: {
          name = system;
          value = {
            home-manager = home-manager.packages.${system}.default;
          };
        }) systems
      );
    };
}
