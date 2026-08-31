# ActionGesture

[English](README.md)

给 iPhone 的操作按钮增加单击、双击和长按手势，每个手势都可以单独选择系统动作。

设置界面直接接在系统原生的“操作按钮”页面上，动作列表也是系统自己的，包括“无”。手电筒、静音模式、快捷指令、相机等原生动作都可以照常使用。

本版本移除了按手机方向区分动作的功能，并新增“快捷动作”菜单：关闭、微信扫码、微信付款、支付宝扫码和支付宝付款。系统动作优先；只有系统动作选择为“无”时，才会执行对应快捷动作。

## 功能

- 单击、双击、长按分别设置动作
- 快捷动作：关闭、微信扫码、微信付款、支付宝扫码和支付宝付款
- 系统动作优先于快捷动作
- 支持简体中文、繁体中文、英文、越南语和阿拉伯语

## 使用

安装后打开：

```text
设置 > 操作按钮
```

页面右上角可以切换单击、双击和长按，以及选择快捷动作。

选择手势或方向后，直接在下面的系统动作列表里设置即可。

## 安装包

`releases.sh` 会在 `packages/` 目录生成三个包：

| 文件 | 越狱环境 |
| --- | --- |
| `ActionGesture_0.0-3-arm.deb` | rootful |
| `ActionGesture_0.0-3-arm64.deb` | rootless |
| `ActionGesture_0.0-3-arm64e.deb` | RootHide |

需要一台带操作按钮的 iPhone，系统版本为 iOS 17 或更高。

## 构建

一次生成三个安装包：

```sh
./releases.sh
```

单独构建：

```sh
# rootful
make package FINALPACKAGE=1

# rootless
make package SCHEME=rootless FINALPACKAGE=1

# RootHide
make package SCHEME=roothide FINALPACKAGE=1
```
