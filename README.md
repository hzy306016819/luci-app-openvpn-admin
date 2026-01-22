# luci-app-openvpn-admin

[![GitHub Release](https://img.shields.io/github/v/release/YOUR_USERNAME/luci-app-openvpn-admin)](https://github.com/YOUR_USERNAME/luci-app-openvpn-admin/releases)
[![Build Status](https://github.com/YOUR_USERNAME/luci-app-openvpn-admin/workflows/Build%20luci-app-openvpn-admin/badge.svg)](https://github.com/YOUR_USERNAME/luci-app-openvpn-admin/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

一个功能完整的 OpenVPN 管理界面插件，适用于 OpenWrt/LEDE/ImmortalWrt 系统。

## 功能特性

### 🚀 核心功能
- **实时状态监控**：实时显示 OpenVPN 服务状态和连接客户端
- **客户端管理**：生成客户端配置文件，支持一键下载
- **服务端配置**：可视化配置 OpenVPN 服务器参数
- **日志查看**：实时查看 OpenVPN 日志，支持自动刷新和过滤
- **黑名单管理**：基于客户端 CN 的黑名单系统
- **证书管理**：支持重置所有证书

### 🔧 技术特性
- 基于 OpenVPN Management Interface 实时获取连接状态
- 集成 EasyRSA 进行证书管理
- 支持自动刷新和实时流量监控
- 完整的 LuCI 界面集成
- 支持多种架构（x86_64, ARM, MIPS）

## 系统要求

- OpenWrt 21.02 或更高版本
- LuCI 框架
- OpenVPN（包含 management 接口支持）
- EasyRSA（用于证书管理）

## 安装方法

### 方法一：在线安装（推荐）

1. 登录 OpenWrt/LEDE/ImmortalWrt 的 LuCI 界面
2. 进入 `系统` → `软件包`
3. 更新软件包列表
4. 搜索 `luci-app-openvpn-admin` 并安装

### 方法二：手动安装 IPK

1. 从 [Releases 页面](https://github.com/YOUR_USERNAME/luci-app-openvpn-admin/releases) 下载对应架构的 IPK 文件
2. 通过 SSH 登录路由器
3. 上传并安装 IPK 文件：
   ```bash
   opkg install luci-app-openvpn-admin_*.ipk
