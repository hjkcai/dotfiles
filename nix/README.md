# 在新机器上部署

这份配置用 Home Manager 管理当前用户的命令和点文件。它不安装系统，也不启动 Docker。运行 `setup.sh` 时可以改主机名、Git 用户名和登录 shell。Linux 用户名取自当前账号，同一份配置可以在 `x86_64-linux` 和 `aarch64-linux` 上使用。

装完之后，新开的 zsh 里会有 Helix、tmux、eza、bat、fd、fzf、git，以及原来 `zshrc` 里的那些别名。Node.js 由 `n` 装到 `~/.n`。机器上还没有 `node` 时，第一次 `setup` 会执行 `n lts`；之后用 `n 22` 或 `n lts` 自己切换，配置不会在下次 setup 时把版本改回去。`home.nix` 里的 `npmGlobals` 会装到 `~/.local/bin`。某一项要锁版本时写成 `http-server@14` 这种 npm 范围。已有的 `~/.zshrc`、Helix 和 tmux 配置会被改成符号链接，原文件备份为同名加 `.backup`。

## 新机器上怎么做

用一个普通用户操作，不要用 root。系统需要是 glibc 的 Linux，例如 Arch、Ubuntu、Fedora。机器上要有 `sudo`，以及 `curl` 或 `wget` 里的一个。缺了下载命令时，`setup.sh` 会在询问主机名之前直接退出。

克隆仓库并运行 `setup.sh`。没有 Nix 时它会自己安装。接着询问主机名和 Git 用户名，按本机架构覆盖这份 Home Manager 配置，并把登录 shell 改成 zsh：

```bash
git clone https://github.com/hjkcai/dotfiles.git
cd dotfiles/nix
./setup.sh
exec zsh
```

每次运行都会重新写受管理的配置文件，包括 `~/.gitconfig`。Git 用户名留空则沿用当前值。`CHINA_MAINLAND` 不是 `0` 时（包含未设置），二进制缓存优先用中科大 `https://mirrors.ustc.edu.cn/nix-channels/store`，官方缓存留作后备。境外机器这样装：

```bash
CHINA_MAINLAND=0 ./setup.sh
```

镜像选择写进 `/etc/nix/nix.conf`，所以需要能 `sudo`。如果 Nix 报 `nix/flake.nix is not tracked by Git`，说明当前目录还不是一次完整克隆，先在仓库根目录执行 `git add nix`，然后再运行 `./setup.sh`。

以后改了 `home.nix`，在 `nix/` 里重新执行 `./setup.sh`。

`CHINA_MAINLAND` 的规则和原来的 `setup.sh` 相同：只有值正好是 `0` 才走官方源，不设置就用国内镜像。zsh 每次启动都会先读 `~/.zshrc-private`，再决定这些地址：

| 用途 | `CHINA_MAINLAND` 不是 `0` | `CHINA_MAINLAND=0` |
|---|---|---|
| Nix 二进制缓存 | 中科大，其次 cache.nixos.org | cache.nixos.org |
| npm | `https://registry.npmmirror.com/` | 不改你原来的 registry |
| Node 二进制（`n`） | `https://mirrors.ustc.edu.cn/node/` | 官方 |
| crates.io | 中科大 sparse index | 不写 `~/.cargo/config.toml` |
| `GITHUB` / `GITHUB_RAW` | `ghfast.top` 前缀 | github.com |
| `flake.lock` 里的源码包 | 同一份 GitHub 压缩包，经 `ghfast.top` 下载 | 直接从 github.com 下载 |

人在境外时，把下面这一行放到 `~/.zshrc-private`，shell 里的 npm、Node 和 GitHub 地址下次开 zsh 就会换掉。Nix 缓存和 Cargo 配置是 `setup.sh` 写的，改完这个变量后要再执行一次 `CHINA_MAINLAND=0 ./setup.sh`。

```bash
export CHINA_MAINLAND=0
```

令牌、代理账号和其他不能进仓库的内容也放在这个文件里。Home Manager 不会覆盖它。国内模式下会写入 `~/.cargo/config.toml`，用来把 crates.io 指到中科大。

`flake.lock` 里的 `https://github.com/...tar.gz` 要保留。后面的 `narHash` 是这些压缩包内容的校验值，换成中科大的 channel 包会得到另一份压缩包，哈希对不上。`CHINA_MAINLAND` 不是 `0` 时，`setup.sh` 把下载地址改写成 `https://ghfast.top/https://github.com/...`，文件内容不变，所以锁文件里的哈希仍然有效。二进制缓存仍然优先走中科大。

## 这份配置不会装的东西

Docker 引擎、Chrome、Cursor、`yay`、内核和开机服务仍然由原来的系统包管理器负责。Termux 还没有接进来。`setup.sh` 里的那些系统步骤是旧流程，新机器不需要再跑它。
