# 让 agent 操作手机上的 App

[English](phone-automation.md) | 简体中文

Termux 里的 `adb` 连上手机本身以后，运行在 Termux 里的编程 agent 就能像人一样操作任何 App：看屏幕，想下一步，然后点击、滑动、打字。不用 root，不用无障碍服务，也不用装别的 App。只要 agent 能执行 shell 命令、能读图片就行；本文用 Claude Code 和 Antigravity CLI（Gemini）测试过，下文的“Claude”可以换成你用的任何一个 agent。

在 Pixel 10 Pro Fold（Android 17）上实测过：Claude 打开 Duolingo，找到当前进行中的课，从头做到尾，翻译、配对、填空、打字题一道没错。听力题和口语题用 App 自带的「现在不方便听/说」按钮跳过了，因为 Claude 听不到声音，也没法说话。拿来测试很有意思，拿来学习就不行了：连续天数是保住了，可学到东西的只有模型。不建议这么做。

> 请遵守各个 App 的用户协议。很多 App 不允许用自动化程序使用它的服务，这套方法适合自己做实验、做测试，或者用于无障碍需求，不要拿来刷分刷奖励。付款、转账、替你给别人发消息这类操作，不要让 Claude 在你没逐步确认的情况下做。

## 准备

先按 [setup.zh-CN.md](setup.zh-CN.md) 做一遍：它包含 Termux、agent、把 `adb` 和手机自己配对、说明文件，每一步后面都有检查。折叠屏还要查屏幕 ID：

```sh
adb shell dumpsys SurfaceFlinger --display-id
```

## 循环：看、想、做

agent 每一步都先看屏幕，决定做什么，再执行。

**默认用截图来看。** `adb exec-out screencap -p > $TMPDIR/s.png` 用不了一秒，人能看到的它都能看到，包括图标、图片和网页内容。

**需要时再加上界面元素列表。** `uiautomator dump` 会把屏幕上的元素列成文字，带精确的点击坐标，也比图片省 token。但只要屏幕上有动画，它就要 10 秒以上，而且画布、游戏和网页视图里的内容它基本看不到。画面静止、又需要精确坐标或者要读大量文字时再用它。下面这个小脚本会保存截图，并列出所有带文字、带描述或可点击的元素，附上它们的点击中心坐标（屏幕像素）：

```sh
#!/data/data/com.termux/files/usr/bin/bash
# look.sh：截屏，并列出界面元素和点击坐标
# 用法：ANDROID_SERIAL=127.0.0.1:<端口> DISPLAY_ID=<屏幕ID> ./look.sh [out.png]
OUT=${1:-$TMPDIR/look.png}
adb exec-out screencap ${DISPLAY_ID:+-d $DISPLAY_ID} -p > "$OUT"
adb shell uiautomator dump --compressed /sdcard/ui.xml >/dev/null 2>&1
adb shell cat /sdcard/ui.xml | tr '>' '\n' | awk '
function attr(s,n){ if (match(s, n "=\"[^\"]*\"")) return substr(s,RSTART+length(n)+2,RLENGTH-length(n)-3); return "" }
/<node/ { t=attr($0,"text"); d=attr($0,"content-desc"); id=attr($0,"resource-id"); sub(/.*\//,"",id)
  c=attr($0,"clickable"); b=attr($0,"bounds")
  if (t=="" && d=="" && c!="true") next
  gsub(/[\[\]]/," ",b); split(b,p,/[ ,]+/)
  printf "%-38s | %-22s | %-24s %s (%d,%d)\n", substr(t,1,38), substr(d,1,22), substr(id,1,24), (c=="true"?"CLICK":""), (p[2]+p[4])/2, (p[3]+p[5])/2 }'
```

列表能正常读出来的时候，光看文字往往就够操作了。列表说不清的地方（比如只有图标的按钮、游戏类画面），或者要确认结果时，再回去看截图。

操作命令：

```sh
adb shell input tap X Y            # 点击（坐标取自 look.sh）
termux-clipboard-set "hello"; adb shell input keyevent 279   # 用粘贴来输入文字（见下文）
adb shell input swipe X1 Y1 X2 Y2 300
adb shell input keyevent BACK
adb shell am start -n <包名>/<Activity>   # 不要用 monkey 启动 App（见下文）
```

## 给 agent 的说明文件

agent 需要知道怎么操作手机、该在哪里停下。[phone/AGENTS.zh-CN.md](../phone/AGENTS.zh-CN.md) 是一份模板，写了操作方法和下面这些规则。把它复制到启动 agent 的目录里（Claude Code 用 `CLAUDE.md`，Antigravity CLI 用 `AGENTS.md` 或 `GEMINI.md`），并填好关于你这台手机的一节。

## act.sh：操作后等屏幕稳定

[phone/act.sh](../phone/act.sh) 执行一个或多个操作，屏幕一停止变化就返回，并附上最新截图。它用来替代固定的 `sleep`：固定等待要么太短（点击丢失），要么太长。

```sh
phone/act.sh tap 540 1200                       # 点击，等屏幕稳定，截图
phone/act.sh tap 540 300 paste "milk tea" key 66
phone/act.sh -u swipe 540 1800 540 600          # -u 同时打印界面元素列表
```

在设置 App 里走同样的四步，它用了 28.8 秒，分开执行点击、sleep、截图要 47.8 秒。

## 直接在手机上发指令（遥控）

不一定要在终端里打字。在 Termux 里启动 agent 并打开遥控，然后在同一台手机上用它自己的 App 或网页和它对话。agent 会打开目标 App 操作，停下时切回它的客户端。

- **Claude Code**：在项目目录里运行 `claude remote-control`（先在这个目录运行一次 `claude`，接受信任提示），然后在 Claude App 里选这台设备新建会话。
- **Antigravity CLI**：在 `tmux` 里运行 `agy --remote-control`，然后在浏览器里打开它打印的链接。见 [antigravity.zh-CN.md](antigravity.zh-CN.md)。

有两点要注意。agent 的客户端和它操作的 App 轮流占用屏幕，所以要告诉 agent 停下时切回来（模板里写了）。另外，点击或按键如果误落在客户端上，会把会话停掉：`keyevent 111`（Esc）两次按中了 Claude App 的停止按钮。

## 实测结果

两次用的是同一句提示词，都从手机上的客户端发出：“打开 DoorDash，帮我在最近的糖水（Tong Sui）点一杯奶茶，种类你来选，停在结账页面”。Pixel 10 Pro Fold，折叠状态，只用截图。

| Agent | 模型 | 客户端 | 结果 | 用时 |
| --- | --- | --- | --- | --- |
| Claude Code | Sonnet 5.5，high | Claude App | 到达结账页，没有下单 | 约 1.5 分钟 |
| Antigravity CLI 1.5.18 | Gemini 4 Hydrogen，high | Chrome 里的网页 | 到达结账页，没有下单 | 约 5 分钟 |

每个 agent 只跑了一次，用时只能粗略参考。

## 分屏：让 Termux 一直留在屏幕上（折叠屏、平板）

屏幕大的话，可以把 App 放在右半边，Termux 留在左半边。这样你能一直看着 Claude 在做什么，随时打断。先打开 App，查到它的任务 ID，然后在 Termux 位于前台时，把 App 移到侧边：

```sh
adb shell am stack list | grep <包名>          # 输出形如 "taskId=12345: <包名>/..."
adb shell dumpsys activity service SystemUIService WMShell splitscreen moveToSideStage <taskId> 1
# 1 = 右边（或下边），0 = 左边（或上边）
adb shell dumpsys activity service SystemUIService WMShell splitscreen exitSplitScreen <taskId>   # 退出分屏
```

在 Pixel 10 Pro Fold 的内屏上，分屏后 Termux 占 x 0–1026，App 占 x 1050–2076。`uiautomator` 给的仍然是整个屏幕的坐标，所以 `look.sh` 和 `input tap` 都不用改。

- **主要适合折叠屏和平板。** 普通手机的半个屏幕太窄，多数 App 会挤得没法用。普通手机上还是让 App 占满全屏，用完再切回 Termux。
- **当心键盘。** Termux 有焦点时，它的软键盘会挡住**左右两边**的下半部分，而 App 的「继续」「检查」这类按钮常常就在那里。点屏幕下方之前先看一眼截图，或者先把键盘收起来。

## 踩过的坑

- **点击之间要停一下。** 很多 App 每次点击后会播动画，动画期间收到的点击会被丢掉。配对题里间隔 0.6 秒的点击丢了一部分，间隔 1.3 秒就都正常。点完一串之后，再跑一次 `look.sh` 确认状态，不要想当然。
- **没看过的页面别闭着眼睛连点。** 课程结束后，我用一个循环一直点屏幕底部正中的按钮，结果连续点过了好几页奖励和推销页面（送宝石、免费试用、「邀请好友加入家庭方案」），事后已经说不清每一下选了什么。非例行的页面要逐页读清楚，按按钮的文字去点。
- **`uiautomator dump` 不是什么都能看到。** 画在 canvas 或游戏视图里的内容只会显示成一个大节点，这种情况要看截图。
- **坐标是屏幕像素。** `uiautomator` 给的 bounds 和 `input tap` 用的是同一套坐标，但缩小后的截图预览不是，所以坐标要取自 dump。
- **不分屏的话，App 会占住整个屏幕。** Claude 操作期间你不能用手机，中途切走会让 Claude 点到别的 App 上。结束后用 `adb shell am start -n com.termux/.app.TermuxActivity` 切回 Termux。折叠屏和平板请用上面的分屏。
- **不要用 `monkey` 打开 App。** `adb shell monkey -p <包名> ...` 拿来启动 App 很方便，但它退出时会打开自动旋转（折叠屏上连当前折叠状态的那一项也会改）。用户的屏幕方向锁定反复被解开，直到所有启动都改成 `am start -n <包名>/<Activity>` 才好。
- **输入文字用粘贴。** `input text` 会经过输入法。自动纠错把 “Tang Shui” 改成了 “Tango Shui”；在中文输入状态下，文字进了候选栏而不是输入框。先设置剪贴板再发 `keyevent 279`（粘贴）可以避开这两个问题。
- **想快就用截图，少用 `uiautomator dump`。** 屏幕上有动画时，一次 dump 要 10 秒以上。有一次为了读一个很长的菜单，逐页 dump 花了三分多钟；改用截图加 App 自带的搜索后，同样的任务只用了一分半。
- **有些 App 禁止截屏**（`FLAG_SECURE`，银行、支付类常见），截出来是黑的，但 `uiautomator` 可能仍然读得到元素。
- **声音处理不了。** Claude 听不到手机发出的声音，依赖声音的操作需要有文字替代方案。

## 限制

- 无线调试要连 Wi-Fi；重启或换网络后连接端口会变，所以没法长期无人值守。
- 锁屏时用不了。
