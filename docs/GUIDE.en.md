[Today](../README.en.md) · [Русский](GUIDE.md) · **English**

# Today user guide

Installation, task controls, startup, and data transfer on Mac and Windows.

## Download Today

**Current version: 1.6.1 for Mac and Windows.** Choose your computer below.
You do not need a GitHub account to download the app.

| Your computer | Download |
| --- | --- |
| **Mac · macOS 13 Ventura or later** — one app for Intel and Apple Silicon | **[Download for Mac](https://github.com/IwanBelenko/TodayBar/releases/download/v1.6.1/Today-1.6.1-mac.zip)** |
| **Windows 11 · Intel or AMD** — most PCs and laptops | **[Download for Windows](https://github.com/IwanBelenko/TodayBar/releases/download/v1.6.1/Today-1.6.1-windows-x64.zip)** |
| **Windows 11 · ARM** — such as Snapdragon laptops | **[Download for Windows ARM](https://github.com/IwanBelenko/TodayBar/releases/download/v1.6.1/Today-1.6.1-windows-arm64.zip)** |

Not sure which Windows download you need? Search for **System Information** in Start
and check **System Type**: `x64` means the standard Windows download, `ARM64` means
Windows ARM. [Microsoft's guide](https://www.microsoft.com/en-us/software-download/windows11arm64).

[What's new in 1.6.1](https://github.com/IwanBelenko/TodayBar/releases/tag/v1.6.1) ·
[Previous releases](https://github.com/IwanBelenko/TodayBar/releases)

<details>
<summary>What about Windows 10 or older systems?</summary>

Windows 10 compatibility depends on the edition and its ESU/LTSC support. See the
[.NET 10 requirements](https://learn.microsoft.com/en-us/dotnet/core/install/windows).
There is no separate build for older systems. This version of Today does not support
Windows 7/8, 32-bit Windows, or macOS earlier than 13.

</details>

## Install

### Mac

1. Download the Mac ZIP above and double-click it to extract the app.
2. Move `Today.app` to **Applications** and open it.
3. Look for the checkmark icon in the menu bar at the top of your screen.

The app is not notarized by Apple. If macOS blocks the first launch, check that you
downloaded it from this repository. If you trust the app, go to **System Settings →
Privacy & Security** and use **Open Anyway**, if available.
[Apple's explanation of this warning](https://support.apple.com/en-us/102445).

### Windows

1. Download the ZIP for your processor above.
2. Right-click the ZIP → **Extract All**. Use a permanent folder, such as `Documents\Today`.
3. Open the extracted `Today.exe`. You do not need to install .NET separately.
4. Find the checkmark icon next to the clock. If it is hidden, expand the tray icons.

The Windows app does not yet have a verified publisher signature, so SmartScreen may
show a warning. Do not disable Windows security. If your work computer blocks the app,
contact your administrator.

**Updating:** quit the old app from its tray/menu-bar menu, then replace it with the
new file. Your saved tasks remain in place. If you move the Windows app to another
folder, turn `Launch at Startup` off and on again to update its startup path.

## Language

**Language:** Today uses Russian when your system's primary language is Russian,
and English otherwise. This applies to both Mac and Windows. Restart Today after
changing the system language. Your task text and custom category names stay unchanged.

## Adding tasks

Type a task and press **Enter** to add it. **Shift + Enter** starts a new line.
Use a task's **`…`** menu to change its priority, deadline, or category, copy its text, or delete it.

## Launch at startup

Right-click the Today icon and enable `Launch at Startup`. Click again to turn it off.
On Windows, this applies only to your user account and does not require administrator rights.

On Mac, you can also manage startup manually in **System Settings → General → Login Items**:
add `Today.app` from Applications.

## Controls

| Action | Result |
| --- | --- |
| Hover over the icon | Windows: no window opens. Mac: quick preview |
| Left-click the icon | Windows: open or hide the window. Mac: pin or close it |
| Right-click the icon | Open the app menu |
| Click Today / History | Switch between current tasks and history |
| Select a category | Filter tasks, history, and counters; the selection stays when switching tabs |
| Click `+` next to categories | Create a custom category |
| Right-click a custom category | Delete the category without deleting its tasks |
| `⌘F` / `Ctrl+F` | Focus search in the current tab and category |
| `Esc` in search, or the clear button | Clear the search |
| Task `…` → Priority | Set or remove priority |
| Task `…` → Add / Change due date… | Add or edit the deadline |
| Click the time field | Type a time manually |
| `−` / `+` next to the time | Adjust by 15 minutes |
| `⌘C` / `⌘V` / `⌘X`, or `Ctrl` on Windows | Copy, paste, or cut text |
| Right-click a completed task | Copy its full text |
| `Enter` while editing | Save the task |
| `Shift + Enter` | Insert a line break |
| Click the round checkbox | Complete or restore a task |

Search matches all entered words, including text across line breaks. Switching tabs
keeps both the query and category. Progress and counters follow the category, but are
not narrowed by search. Adding a task clears the query.

History's clear action removes completed tasks only from the selected category; in
All, it clears all history. Confirmation is required. Bulk clearing is hidden
while searching.

Priority order is **3 flames → 2 → 1 → no flames**. Within the same priority, unfinished
tasks keep creation order and completed tasks use newest completion first. Completed
tasks remain in their own section; history keeps its day groups and sorts by priority
within each day. Existing and new tasks have no priority by default.

## Your data

Mac stores tasks and categories here:

```text
~/Library/Application Support/TodayBar/tasks.json
~/Library/Application Support/TodayBar/categories.json
```

Windows uses `%APPDATA%\TodayBar\tasks.json` and `%APPDATA%\TodayBar\categories.json`.
On Windows, a `.bak` file keeps the previous saved version. A damaged file is reported
as a read error, not silently replaced with an empty list.

Uninstalling the app does not automatically delete these files. To transfer your tasks
between computers or platforms, quit Today on both computers, make backups, and copy
**both JSON files** into the destination's TodayBar data folder. This replaces the
destination's list; it does not merge lists. Deadlines are stored in UTC and displayed
in local time. There is no automatic sync.

### Windows reminders

While running in the tray, Today checks deadlines every 15 seconds and shows a system
notification. Overdue tasks stay marked, and missed deadlines are checked at the next
launch. Each deadline is notified once per session. No reminders are sent after Today
has quit or while the PC is off. Enable startup if you want reminders whenever you use
your computer. Do Not Disturb and Windows notification settings can hide alerts.

## Privacy

Today does not use the network or send analytics. Data stays on your computer.
On Mac, notification permission is requested when you first add a deadline.
On Windows, Today uses system tray notifications; the current user's startup registry
entry is changed only when you choose `Launch at Startup`. Startup is never enabled
automatically on first launch.

[Back to Today](../README.en.md) · [For developers](DEVELOPMENT.en.md)
