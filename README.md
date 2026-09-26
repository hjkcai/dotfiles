# dotfiles

The nice dotfiles and setup scripts for me

新机器用 Nix 配置，步骤在 [nix/README.md](nix/README.md)。下面的 `setup.sh` 是旧的安装方式。

Use the following script to install:

### China Mainland

```bash
bash -c "$(curl -fsSL https://mirror.ghproxy.com/raw.githubusercontent.com/hjkcai/dotfiles/master/setup.sh)" && exec zsh
```

### Otherwise

```bash
CHINA_MAINLAND=0 bash -c "$(curl -fsSL https://raw.githubusercontent.com/hjkcai/dotfiles/master/setup.sh)" && exec zsh
```
