# 操作这台安卓手机

你运行在安卓手机的 Termux 里。`adb` 已经通过无线调试连到手机自己，所以你可以像人一样操作任何 App。开始前先用 `adb devices` 确认。

把这个文件复制到你启动 agent 的目录里。多数 agent 读 `AGENTS.md`；Claude Code 读 `CLAUDE.md`，Antigravity CLI 还会读 `GEMINI.md`，按需要复制或软链接成对应的名字。“这台手机”一节请按你的设备修改。

## 操作方法

- 用 `adb shell am start -n <包名>/<Activity>` 打开 App。Activity 可以用 `adb shell cmd package resolve-activity --brief <包名>` 查。
- 看屏幕：截图后用你的读图工具查看，`adb exec-out screencap -p > $TMPDIR/s.png`（多屏设备加 `-d <屏幕ID>`）。
- 操作：`adb shell input tap X Y`、`input swipe X1 Y1 X2 Y2 300`、`input keyevent BACK`。
- 输入文字一律用粘贴，英文也一样：`termux-clipboard-set "文字"; adb shell input keyevent 279`。`input text` 会经过输入法，被自动纠错，或者在中文输入状态下被吞掉。
- 把“操作 + 等待 + 截图”写在同一条命令里，减少来回，例如 `adb shell input tap 540 1200; sleep 2; adb exec-out screencap -p > $TMPDIR/s.png`。本目录的 `./act.sh` 做的就是这件事，并且屏幕一停止变化就返回，例如 `./act.sh tap 540 1200`。
- 每一屏先看清再点，不要连续点过没看过的界面。

## 规则

- **涉及花钱、或者要发给别人的操作，在最后一步之前停下。** 做到结账页或确认页就停，最后的按钮由用户自己点。
- 用户没要求的系统设置不要改。
- 绝不发送 `keyevent 111`（Esc）：如果前台正好是 agent 自己的客户端，它会中断你的会话。
- 停下来时（做完、卡住、等回复），把用户和你对话用的那个 App 切回前台，并说明另一个 App 停在什么状态。
- 如果发现前台不是目标 App，多半是用户切走看别的了。重新打开目标 App 继续。

## 速度

- 用截图。屏幕有动画时 `uiautomator dump` 要 10 秒以上，而且画布和网页视图里的内容基本看不到，只在截图不够用时再用它。
- 不要把整个菜单或列表翻一遍。用 App 自带的搜索，从第一屏结果里选，然后继续。

## 这台手机

- 设备和屏幕：<例如：Pixel 折叠屏，外屏 ID 4619827677550801153>
- 可能用到的 App 和启动 Activity：<包名/Activity>
- 这个 Termux 环境里坏掉的东西：<例如：没有 python>
