# 在 Termux 里用 Antigravity CLI（Gemini）

[English](antigravity.md) | 简体中文

Google 的 Antigravity CLI（`agy`）提供原生 Android 版本，在 Termux 里可以直接运行，不需要 glibc、proot 或补丁。已测试：`agy` 1.5.18，Pixel 10 Pro Fold（Android 17），模型 Gemini 4 Hydrogen。

## 安装和登录

```sh
curl -fsSL https://antigravity.google/cli/install.sh -o install-agy.sh
less install-agy.sh        # 它会识别 Android，下载二进制并校验 sha512
bash install-agy.sh
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
agy                        # 第一次运行：在浏览器里用 Google 账号登录
agy models                 # 列出你的账号能用的模型
```

二进制装在 `~/.local/bin/agy`。Google 的安装文档目前还只列了桌面系统，但安装脚本能处理 Termux。

## 安装时会看到什么

在测试手机上，安装过程没有遇到技术问题。不过有几处看起来像报错，其实不是：

- 每条 `agy` 命令开头都会打印一行 `ERROR: logging before google.Init: ... Initialized Android local timezone to ...`。这只是一行日志，不是失败。
- 安装脚本会警告 `~/.local/bin` 不在 `PATH` 里。上面那行 `export PATH=...` 就是解决这个的；在那之前可以用 `~/.local/bin/agy` 运行。
- `--mode auto` 会打印一条警告，然后按默认模式继续（见下文）。

和 Claude Code 不同，`agy` 不需要 glibc，不需要给二进制打补丁，也不需要包装脚本，并且自带 `agy update` 命令（还没在手机上试过）。

## Android 上的权限

Android 上不能用 `--mode auto`：它依赖终端沙箱，这里没有，`agy` 会退回到每条命令都先询问。用来操作手机的话，就是每点一下都要确认一次。

`--dangerously-skip-permissions` 可以去掉这些确认，但这也等于撤掉了模型和你的手机之间唯一的一道关卡。只在你全程盯着的任务里用，所在目录的说明文件要写明 agent 该在哪里停下，并且不要让这样的会话无人看管地开着。

## 说明文件和记忆

`agy` 会读启动目录里的 `AGENTS.md` 和 `GEMINI.md`，以及对所有会话生效的 `~/.gemini/GEMINI.md`。把 [phone/AGENTS.zh-CN.md](../phone/AGENTS.zh-CN.md) 放进项目目录。如果想把另一个 agent 已经摸清的经验（比如 Claude Code 的记忆文件）交给它，把内容复制进 `~/.gemini/GEMINI.md` 即可。复制前先读一遍：这些内容会发给另一家服务商，不想分享的先删掉。

第一次在某个目录启动 `agy` 时，它会问你是否信任这个目录。

## 从浏览器发指令（Remote Control）

把 `agy` 放在 `tmux` 里运行，这样 Termux 切到后台时它也不会停：

```sh
pkg install -y tmux
tmux new -s agy -c ~/projects/phone-demo 'agy --remote-control --model gemini-4-hydrogen-high'
# Ctrl+b d 放到后台；tmux attach -t agy 回来
```

`agy` 会打印一个 `https://antigravity.google.com/r/<id>` 这样的链接。在登录了同一个 Google 账号的浏览器里打开它（手机自己的浏览器或其他设备都行），进入会话，就可以从网页发指令。`agy` 退出后连接随之关闭。

发送前看一眼网页里的模型选择：它有自己的选项，不一定和启动时的 `--model` 一致。
