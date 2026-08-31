# ActionGesture

[简体中文](README_ZH.md)

ActionGesture adds single-press, double-press, and long-press assignments to the iPhone Action Button.

It uses Apple's original Action Button settings page and native action list, including Nothing. System actions such as Flashlight, Silent Mode, Camera, and Shortcuts continue to work as usual. Direction-based assignments were removed; a Quick Action menu now provides Close, WeChat Scan, WeChat Pay, Alipay Scan, and Alipay Pay. Native system actions always take precedence, and quick actions run only when the native action is Nothing.

## Features

- Separate actions for single press, double press, and long press
- Quick actions: Close, WeChat Scan, WeChat Pay, Alipay Scan, and Alipay Pay
- Native system actions take precedence over quick actions
- English, Simplified Chinese, Traditional Chinese, Vietnamese, and Arabic localizations

## Usage

After installation, open:

```text
Settings > Action Button
```

Use the menus in the top-right corner to choose the gesture and quick action. Select a native system action from the list below; the quick action is used only when the native selection is Nothing.

## Packages

Running `releases.sh` creates three packages in `packages/`:

| File | Jailbreak environment |
| --- | --- |
| `ActionGesture_0.0-3-arm.deb` | rootful |
| `ActionGesture_0.0-3-arm64.deb` | rootless |
| `ActionGesture_0.0-3-arm64e.deb` | RootHide |

Requires an iPhone with an Action Button running iOS 17 or later.

## Building

Build all three packages:

```sh
./releases.sh
```

Build a single package:

```sh
# rootful
make package FINALPACKAGE=1

# rootless
make package SCHEME=rootless FINALPACKAGE=1

# RootHide
make package SCHEME=roothide FINALPACKAGE=1
```
