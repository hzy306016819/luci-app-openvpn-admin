# luci-app-openvpn-admin

[![GitHub Release](https://img.shields.io/github/v/release/hzy306016819/luci-app-openvpn-admin)](https://github.com/hzy306016819/luci-app-openvpn-admin/releases)
[![Build Status](https://github.com/hzy306016819/luci-app-openvpn-admin/workflows/Build%20luci-app-openvpn-admin/badge.svg)](https://github.com/hzy306016819/luci-app-openvpn-admin/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

一个功能完整的 OpenVPN 管理界面插件，适用于 OpenWrt/LEDE/ImmortalWrt 系统。
## 重要提示：插件严重依赖MANAGEMENT管理接口。所以openvpn-openssl必须带MANAGEMENT管理接口
- 方法一：在.config文件CONFIG_OPENVPN_openssl_ENABLE_MANAGEMENT=y 
- 方法二：make menuconfig -> Network -> VPN -> openvpn-openssl ->  [*] Enable management server support

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

1. 从 [Releases 页面](https://github.com/hzy306016819/luci-app-openvpn-admin/releases) 下载对应架构的 IPK 文件
2. 通过 SSH 登录路由器
3. 上传并安装 IPK 文件：
   ```bash
   opkg install luci-app-openvpn-admin_*.ipk
# 安装效果图（只在安装好的系统测试过，末测试编译）
<img width="1918" height="880" alt="image" src="https://github.com/user-attachments/assets/7dc22795-2a1d-48f3-9847-1f5e22bcddba" />
<img width="1918" height="880" alt="image" src="https://github.com/user-attachments/assets/1dffeeb0-e778-40bd-9832-2aa6d1249f15" />
<img width="1918" height="880" alt="image" src="https://github.com/user-attachments/assets/ef562183-fbf7-4b30-8cd3-613129c83913" />
<img width="1918" height="880" alt="image" src="https://github.com/user-attachments/assets/a0ac2d44-7fb5-44bf-86f1-185fab269906" />
<img width="1918" height="880" alt="image" src="https://github.com/user-attachments/assets/0ca09a8c-4598-41b8-af83-345e5730afc3" />



# 插件目录结构

```plaintext
luci-app-openvpn-admin/
├── luasrc/
│   ├── controller/
│   │   └── openvpn-admin.lua
│   └── view/
│       └── openvpn-admin/
│           ├── client.htm
│           ├── logs.htm
│           ├── server.htm
│           ├── settings.htm
│           └── status.htm
├── root/
│   ├── etc/
│   │   ├── config/
│   │   │   └── openvpn-admin
│   │   │   └── openvpn
│   │   └── openvpn/
│   │       ├── clean-garbage.sh
│   │       ├── client-connect-cn.sh
│   │       ├── generate-client.sh
│   │       ├── openvpn_ipv6 
│   │       ├── openvpn_hotplug.sh                  
│   │       └── renewcert.sh
│   │        
│   │           
└── Makefile
```
## 文件对应目录
文件目录：
"/usr/lib/lua/luci/controller/openvpn-admin.lua"
"/usr/lib/lua/luci/view/openvpn-admin/status.htm"
"/usr/lib/lua/luci/view/openvpn-admin/client.htm"
"/usr/lib/lua/luci/view/openvpn-admin/server.htm"
"/usr/lib/lua/luci/view/openvpn-admin/logs.htm"
"/usr/lib/lua/luci/view/openvpn-admin/settings.htm"
"/etc/config/openvpn-admin"                                                配置文件
"/etc/config/openvpn"                                                      配置文件
下面需要执行权限的：
"/etc/openvpn/generate-client.sh"                              OpenVPN客户端证书生成和配置文件生成脚本
"/etc/openvpn/client-connect-cn.sh"                          用于检查客户端CN是否在黑名单中
"/etc/openvpn/renewcert.sh"                                       证书重置脚本。这个不需要执行权限
"/etc/openvpn/clean-garbage.sh"                               OpenVPN管理界面垃圾文件清理脚本
"/etc/openvpn/openvpn_ipv6"                                 新增ipv6更新脚本，获取pppoe-wan的地址更新openvpn配置文件的ipv6地址。



## 完整修正后的项目关系树

text

```
luci-app-openvpn-admin/
├── 控制器文件 (Lua)
│   └── openvpn-admin.lua                    # 主控制器
├── 视图模板 (HTM)
│   ├── status.htm                          # 状态页面
│   ├── client.htm                          # 客户端页面
│   ├── server.htm                          # 服务端配置页面
│   ├── logs.htm                            # 日志页面
│   └── settings.htm                        # 设置页面
├── 脚本文件 (需要手动创建)
│   ├── /etc/openvpn/client-connect-cn.sh   # 客户端连接黑名单检查脚本 ★
│   └── /etc/openvpn/renewcert.sh           # 重置所有证书脚本 ★
├── 脚本文件 (自动生成)
│   ├── openvpn_ipv6                        # IPv6自动更新主脚本
│   ├── openvpn_hotplug.sh                  # Hotplug系统脚本
│   ├── clean-garbage.sh                    # 垃圾清理脚本
│   └── generate-client.sh                  # 生成客户端配置脚本
├── 配置文件
│   ├── /etc/config/openvpn-admin           # 插件UCI配置
│   ├── /etc/config/openvpn                 # OpenVPN主配置
│   ├── /etc/openvpn/blacklist.json         # 黑名单文件
│   ├── /etc/openvpn/openvpn_connection_history.json # 连接历史
│   └── /etc/openvpn/pki/                   # 证书目录
├── 系统集成文件
│   ├── /etc/hotplug.d/iface/99-openvpn-admin # Hotplug配置文件（自动生成）
│   └── /etc/crontabs/root                  # Cron定时任务（自动更新）
└── 临时文件目录
    ├── /tmp/openvpn-admin/                 # 临时目录（自动创建）
    ├── /tmp/openvpn-admin/openvpn_ipv6.log # IPv6脚本日志
    └── /tmp/openvpn-admin/hotplug_ipv6.log # Hotplug日志
```



## 脚本创建状态检查表

| 脚本文件             | 是否自动生成 | 状态                   | 备注             |
| :------------------- | :----------- | :--------------------- | :--------------- |
| openvpn_ipv6         | 手动/自动    | ⚠️ 需要手动创建或替换   | 核心IPv6更新脚本 |
| openvpn_hotplug.sh   | 自动生成     | ✅ 保存设置时生成       | Hotplug系统脚本  |
| clean-garbage.sh     | 自动生成     | ✅ 启用清理功能时生成   | 垃圾清理脚本     |
| generate-client.sh   | 自动生成     | ✅ 首次生成客户端时生成 | 客户端配置生成   |
| client-connect-cn.sh | 手动创建     | ⚠️ 需要手动创建         | 黑名单检查脚本   |
| renewcert.sh         | 手动创建     | ⚠️ 需要手动创建         | 证书重置脚本     |
| 99-openvpn-admin     | 自动生成     | ✅ 启用Hotplug时生成    | Hotplug配置文件  |
