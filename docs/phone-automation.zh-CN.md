# 让 Claude 操作手机上的 App

[English](phone-automation.md) | 简体中文

Termux 里的 `adb` 连上手机本身以后，Claude Code 就能像人一样操作任何 App：看屏幕，想下一步，然后点击、滑动、打字。不用 root，不用无障碍服务，也不用装别的 App。

在 Pixel 10 Pro Fold（Android 17）上实测过：Claude 打开一个语言学习 App，找到当前进行中的课，从头做到尾，翻译、配对、填空、打字题一道没错。听力题和口语题用 App 自带的「现在不方便听/说」按钮跳过了，因为 Claude 听不到声音，也没法说话。

> 请遵守各个 App 的用户协议。很多 App 不允许用自动化程序使用它的服务，这套方法请用在自己的实验、测试和无障碍需求上，不要拿来刷分刷奖励。付款、转账、替你给别人发消息这类操作，不要让 Claude 在你没逐步确认的情况下做。

## 准备

先按 [android-dev.zh-CN.md](android-dev.zh-CN.md) 第 5 节，通过无线调试把 `adb` 配对并连接到 `127.0.0.1`。然后查屏幕 ID，折叠屏需要它：

```sh
adb shell dumpsys SurfaceFlinger --display-id
```

## 循环：看、想、做

Claude 每一步都先截屏、读一遍界面元素，决定做什么，再执行。下面这个小脚本负责「看」：保存截图，并列出所有带文字、带描述或可点击的元素，附上它们的点击中心坐标（屏幕像素）：

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

大多数时候光看这份文字列表就能操作，比看截图省很多 token。只有列表说不清的时候才需要看截图，比如只有图标的按钮、游戏类画面，或者要确认结果。

操作命令：

```sh
adb shell input tap X Y            # 点击（坐标取自 look.sh）
adb shell input text hello         # 在当前输入框里打字
adb shell input swipe X1 Y1 X2 Y2 300
adb shell input keyevent BACK
adb shell am start -n <包名>/<Activity>   # 或：monkey -p <包名> -c android.intent.category.LAUNCHER 1
```

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
- **不分屏的话，App 会占住整个屏幕。** Claude 操作期间你不能用手机，中途切走会让 Claude 点到别的 App 上。结束后用 `monkey -p com.termux -c android.intent.category.LAUNCHER 1` 切回 Termux。折叠屏和平板请用上面的分屏。
- **有些 App 禁止截屏**（`FLAG_SECURE`，银行、支付类常见），截出来是黑的，但 `uiautomator` 可能仍然读得到元素。
- **声音碰不到。** Claude 听不到手机发出的声音，依赖声音的操作需要有文字替代方案。

## 限制

- 无线调试要连 Wi-Fi；重启或换网络后连接端口会变，所以没法长期无人值守。
- 锁屏时用不了。
