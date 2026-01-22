# luci-app-openvpn-admin
# 一、完整的项目结构
luci-app-openvpn-admin/
├── .github/
│   └── workflows/
│       └── build-release.yml    # GitHub Actions工作流
├── luci-app-openvpn-admin/
│   ├── Makefile                 # 插件Makefile
│   ├── root/
│   │   ├── etc/
│   │   │   ├── config/
│   │   │   │   └── openvpn-admin
│   │   │   └── openvpn-admin/
│   │   │       ├── generate-client.sh
│   │   │       ├── client-connect-cn.sh
│   │   │       ├── renewcert.sh
│   │   │       └── clean-garbage.sh
│   │   └── usr/
│   │       └── lib/
│   │           └── lua/
│   │               └── luci/
│   │                   ├── controller/
│   │                   │   └── openvpn-admin.lua
│   │                   └── view/
│   │                       └── openvpn-admin/
│   │                           ├── status.htm
│   │                           ├── client.htm
│   │                           ├── server.htm
│   │                           ├── logs.htm
│   │                           └── settings.htm
│   └── files/
│       └── README.txt           # 安装说明
├── scripts/
│   ├── setup-environment.sh     # 环境设置脚本
│   └── check-dependencies.sh    # 依赖检查脚本
├── LICENSE
├── README.md
└── .gitignore

# OpenVPN 管理界面 - 安装指南
## 概述
该LuCI应用为OpenWrt/LEDE/ImmortalWrt路由器上的OpenVPN提供一站式管理界面。

## 功能特性
1. 基于管理接口的实时连接监控
2. 客户端证书的生成与管理
3. 服务端配置编辑器
4. 连接历史记录与日志查看
5. 客户端黑名单管理
6. 证书续签与重置

## 运行要求
1. 支持管理接口的OpenVPN版本
2. 用于证书管理的Easy-RSA工具
3. 集成JSON和网络库的LuCI环境

## 安装步骤
1. 安装所需依赖组件：
   opkg update
   opkg install openvpn-openssl easy-rsa curl openssl-util

2. 安装本应用包：
   opkg install luci-app-openvpn-admin_*.ipk

3. 配置OpenVPN管理接口：
   编辑配置文件 /etc/config/openvpn，为服务端实例添加以下配置项：
   option management '127.0.0.1 7505'
   option management_forget_disconnect '1'

4. 访问管理界面：
   登录LuCI → 进入VPN板块 → 打开OpenVPN管理页面

## 配置说明
应用的配置文件存储于 /etc/config/openvpn-admin

可通过LuCI界面修改默认配置，路径为：
- 系统设置 → VPN → OpenVPN管理 → 配置项

## 故障排查
1. 若无法显示连接状态：
   - 验证OpenVPN管理接口是否已启用
   - 检查OpenVPN运行状态：/etc/init.d/openvpn status
   - 查看日志文件：/tmp/openvpn.log

2. 若证书生成失败：
   - 确认已安装Easy-RSA：opkg install easy-rsa
   - 检查文件权限：chmod 755 /etc/easy-rsa

3. 若LuCI中未显示该管理界面：
   - 重启uhttpd服务：/etc/init.d/uhttpd restart
   - 清除浏览器缓存

## 技术支持
如需反馈问题或提出功能需求，请访问：
https://github.com/[你的用户名]/luci-app-openvpn-admin

## 许可证
采用GPL-3.0仅需遵守版许可证协议


luci-app-openvpn-admin/
├── Makefile
├── README.md
├── LICENSE
├── .github/
│   └── workflows/
│       └── build.yml
├── files/
│   ├── etc/
│   │   ├── config/
│   │   │   └── openvpn-admin
│   │   └── openvpn-admin/
│   │       ├── generate-client.sh
│   │       ├── client-connect-cn.sh
│   │       ├── renewcert.sh
│   │       └── clean-garbage.sh
│   └── usr/
│       └── lib/
│           └── lua/
│               └── luci/
│                   ├── controller/
│                   │   └── openvpn-admin.lua
│                   └── view/
│                       └── openvpn-admin/
│                           ├── client.htm
│                           ├── logs.htm
│                           ├── server.htm
│                           ├── settings.htm
│                           └── status.htm
└── package/
    └── luci-app-openvpn-admin/
        └── Makefile
