# OpenWrt/LEDE/ImmortalWrt 包构建 Makefile
# 这是 OpenWrt SDK 使用的标准包 Makefile

include $(TOPDIR)/rules.mk

# 包信息
PKG_NAME:=luci-app-openvpn-admin
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

# 构建目录
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

# 包含 OpenWrt 包定义
include $(INCLUDE_DIR)/package.mk

# LuCI 包定义
include $(INCLUDE_DIR)/luci.mk

# 包定义
define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=OpenVPN Management Interface
  PKGARCH:=all
  DEPENDS:= \
    +luci-base \
    +openvpn-openssl \
    +luci-lib-jsonc \
    +easy-rsa \
    +curl \
    +openssl-util \
    +netcat-openbsd \
    +bash
endef

# 包描述
define Package/$(PKG_NAME)/description
  一个功能完整的 OpenVPN 管理界面，包含状态监控、客户端管理、服务端配置、日志查看和设置功能。
  支持基于CN的黑名单管理、客户端证书生成、实时连接监控等。
  
  A comprehensive OpenVPN management interface for OpenWrt/LEDE/ImmortalWrt.
  Features include client management, certificate generation, connection monitoring,
  and server configuration.
  
  主要功能:
  - 实时 OpenVPN 连接状态监控
  - 客户端配置生成和证书管理
  - 服务端配置管理
  - 日志查看和过滤
  - 客户端黑名单管理
  - 多语言支持 (中文/英文)
endef

# 构建准备阶段
define Build/Prepare
	# 创建构建目录
	mkdir -p $(PKG_BUILD_DIR)
endef

# 配置阶段
define Build/Configure
endef

# 编译阶段
define Build/Compile
endef

# 安装阶段 - 这是最重要的部分，定义文件如何安装到路由器
define Package/$(PKG_NAME)/install
	# 创建基本目录结构
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/openvpn-admin
	$(INSTALL_DIR) $(1)/tmp/openvpn-admin
	$(INSTALL_DIR) $(1)/etc/openvpn-admin/template
	
	# 安装 LuCI 控制器
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/openvpn-admin.lua \
		$(1)/usr/lib/lua/luci/controller/openvpn-admin.lua
	
	# 安装 LuCI 视图文件
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/openvpn-admin
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-admin/client.htm \
		$(1)/usr/lib/lua/luci/view/openvpn-admin/client.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-admin/server.htm \
		$(1)/usr/lib/lua/luci/view/openvpn-admin/server.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-admin/status.htm \
		$(1)/usr/lib/lua/luci/view/openvpn-admin/status.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-admin/logs.htm \
		$(1)/usr/lib/lua/luci/view/openvpn-admin/logs.htm
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-admin/settings.htm \
		$(1)/usr/lib/lua/luci/view/openvpn-admin/settings.htm
	
	# 安装 UCI 配置文件
	$(INSTALL_DATA) ./files/etc/config/openvpn-admin \
		$(1)/etc/config/openvpn-admin
	
	# 安装脚本文件（设置执行权限）
	$(INSTALL_BIN) ./files/etc/openvpn-admin/generate-client.sh \
		$(1)/etc/openvpn-admin/generate-client.sh
	$(INSTALL_BIN) ./files/etc/openvpn-admin/client-connect-cn.sh \
		$(1)/etc/openvpn-admin/client-connect-cn.sh
	$(INSTALL_BIN) ./files/etc/openvpn-admin/clean-garbage.sh \
		$(1)/etc/openvpn-admin/clean-garbage.sh
	$(INSTALL_BIN) ./files/etc/openvpn-admin/renewcert.sh \
		$(1)/etc/openvpn-admin/renewcert.sh
	
	# 安装模板文件
	$(INSTALL_DATA) ./files/etc/openvpn-admin/template/server.template \
		$(1)/etc/openvpn-admin/template/server.template
	
	# 创建空的配置文件（如果不存在）
	$(INSTALL_DIR) $(1)/etc/openvpn
	$(INSTALL_DIR) $(1)/etc/openvpn/pki
	
	# 创建运行时目录
	$(INSTALL_DIR) $(1)/tmp/openvpn-admin
	$(INSTALL_DIR) $(1)/var/log
	
	# 设置目录权限
	$(SED) 's/^\([[:space:]]*\)$(INSTALL_DIR)/\1$(INSTALL_DIR)/' $(1)/tmp/openvpn-admin
endef

# 后安装脚本 - 安装后执行
define Package/$(PKG_NAME)/postinst
#!/bin/sh
# 只在真实系统上执行，不在构建环境中执行
if [ -z "$${IPKG_INSTROOT}" ]; then
	# 创建必要的目录
	echo "创建必要的目录..."
	mkdir -p /etc/openvpn-admin/template 2>/dev/null
	mkdir -p /tmp/openvpn-admin 2>/dev/null
	mkdir -p /etc/openvpn/pki 2>/dev/null
	mkdir -p /etc/openvpn-admin 2>/dev/null
	
	# 设置脚本执行权限
	echo "设置脚本执行权限..."
	chmod 755 /etc/openvpn-admin/*.sh 2>/dev/null || true
	chmod 755 /tmp/openvpn-admin 2>/dev/null || true
	
	# 初始化 UCI 配置（如果不存在）
	if ! uci -q get openvpn-admin.@settings[0] >/dev/null 2>&1; then
		echo "初始化 OpenVPN Admin 配置..."
		
		# 创建默认配置
		uci batch << EOF
set openvpn-admin.settings=settings
set openvpn-admin.settings.openvpn_instance='myvpn'
set openvpn-admin.settings.openvpn_config_path='/etc/config/openvpn'
set openvpn-admin.settings.refresh_enabled='1'
set openvpn-admin.settings.refresh_interval='1'
set openvpn-admin.settings.history_size='20'
set openvpn-admin.settings.blacklist_enabled='1'
set openvpn-admin.settings.blacklist_duration='300'
set openvpn-admin.settings.log_file='/tmp/openvpn.log'
set openvpn-admin.settings.history_file='/etc/openvpn-admin/openvpn_connection_history.json'
set openvpn-admin.settings.blacklist_file='/etc/openvpn-admin/blacklist.json'
set openvpn-admin.settings.easyrsa_dir='/etc/easy-rsa'
set openvpn-admin.settings.easyrsa_pki='/etc/easy-rsa/pki'
set openvpn-admin.settings.openvpn_pki='/etc/openvpn/pki'
set openvpn-admin.settings.logs_refresh_enabled='1'
set openvpn-admin.settings.logs_refresh_interval='10'
set openvpn-admin.settings.logs_display_lines='1000'
set openvpn-admin.settings.generate_client_script='/etc/openvpn-admin/generate-client.sh'
set openvpn-admin.settings.renew_cert_script='/etc/openvpn-admin/renewcert.sh'
set openvpn-admin.settings.temp_dir='/tmp/openvpn-admin'
set openvpn-admin.settings.clean_garbage_enabled='0'
set openvpn-admin.settings.clean_garbage_time='4:50'
set openvpn-admin.settings.clean_garbage_script='/etc/openvpn-admin/clean-garbage.sh'
set openvpn-admin.settings.server_template_path='/etc/openvpn-admin/template/server.template'
commit openvpn-admin
EOF
		
		echo "✅ 默认配置已创建"
	fi
	
	# 检查并创建必要的系统目录
	if [ ! -d "/etc/easy-rsa" ]; then
		echo "⚠️  警告: /etc/easy-rsa 目录不存在，EasyRSA 可能未安装"
		echo "请安装 easy-rsa 包: opkg install easy-rsa"
	fi
	
	if [ ! -f "/etc/openvpn-addon.conf" ]; then
		echo "创建 OpenVPN 附加配置文件..."
		touch /etc/openvpn-addon.conf
	fi
	
	# 重新加载服务
	echo "重新加载服务..."
	/etc/init.d/uhttpd reload >/dev/null 2>&1 || true
	/etc/init.d/rpcd reload >/dev/null 2>&1 || true
	/etc/init.d/cron reload >/dev/null 2>&1 || true
	
	echo ""
	echo "=========================================="
	echo "✅ OpenVPN Admin 插件安装完成!"
	echo "=========================================="
	echo ""
	echo "🌐 访问地址:"
	echo "  1. 打开浏览器访问路由器管理界面"
	echo "  2. 进入 'VPN' -> 'OpenVPN 管理'"
	echo ""
	echo "📋 功能菜单:"
	echo "  - 状态: 查看 OpenVPN 连接状态"
	echo "  - 客户端: 生成客户端配置和证书"
	echo "  - 服务端: 配置 OpenVPN 服务器"
	echo "  - 日志: 查看 OpenVPN 日志"
	echo "  - 设置: 配置插件选项"
	echo ""
	echo "🔧 需要安装的依赖包:"
	echo "  - openvpn-openssl (OpenVPN 服务)"
	echo "  - easy-rsa (证书管理)"
	echo "  - luci-lib-jsonc (JSON 支持)"
	echo ""
	echo "📝 首次使用建议:"
	echo "  1. 在'设置'页面检查配置"
	echo "  2. 在'客户端'页面生成第一个客户端配置"
	echo "  3. 在'状态'页面查看连接情况"
	echo "=========================================="
fi

exit 0
endef

# 预删除脚本 - 删除前执行
define Package/$(PKG_NAME)/prerm
#!/bin/sh
# 只在真实系统上执行，不在构建环境中执行
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "准备卸载 OpenVPN Admin 插件..."
	
	# 停止可能相关的服务
	echo "停止相关服务..."
	/etc/init.d/uhttpd reload >/dev/null 2>&1 || true
	
	# 清理 cron 任务
	echo "清理定时任务..."
	if [ -f "/etc/crontabs/root" ]; then
		sed -i '/# OpenVPN管理插件垃圾清理任务/d' /etc/crontabs/root
		sed -i '/clean-garbage.sh/d' /etc/crontabs/root
		/etc/init.d/cron reload >/dev/null 2>&1 || true
	fi
	
	# 备份配置文件
	echo "备份配置文件..."
	if [ -f "/etc/config/openvpn-admin" ]; then
		cp /etc/config/openvpn-admin /tmp/openvpn-admin-backup-$(date +%Y%m%d%H%M%S).conf
		echo "配置文件已备份到 /tmp/"
	fi
	
	echo "✅ 卸载准备完成"
fi

exit 0
endef

# 后删除脚本 - 删除后执行
define Package/$(PKG_NAME)/postrm
#!/bin/sh
# 只在真实系统上执行，不在构建环境中执行
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "清理残留文件..."
	
	# 删除临时目录（但保留用户数据）
	if [ -d "/tmp/openvpn-admin" ]; then
		echo "清理临时目录..."
		rm -rf /tmp/openvpn-admin/* 2>/dev/null || true
	fi
	
	# 重新加载 LuCI
	echo "重新加载 LuCI..."
	/etc/init.d/uhttpd restart >/dev/null 2>&1 || true
	
	echo "✅ OpenVPN Admin 插件已完全移除"
	echo ""
	echo "📝 注意:"
	echo "  - 配置文件已备份到 /tmp/openvpn-admin-backup-*.conf"
	echo "  - 用户数据文件仍保留在 /etc/openvpn-admin/"
	echo "  - 如需完全清理，请手动删除相关目录"
fi

exit 0
endef

# 定义包构建
$(eval $(call BuildPackage,$(PKG_NAME)))

# 构建信息显示
define Build/ShowInfo
	@echo "=========================================="
	@echo "OpenVPN Admin 插件构建信息"
	@echo "=========================================="
	@echo "包名称:    $(PKG_NAME)"
	@echo "版本:      $(PKG_VERSION)-$(PKG_RELEASE)"
	@echo "架构:      $(PKGARCH)"
	@echo "构建目录:  $(PKG_BUILD_DIR)"
	@echo "依赖包:    $(DEPENDS)"
	@echo ""
	@echo "包含文件:"
	@echo "  - LuCI 控制器: openvpn-admin.lua"
	@echo "  - 视图文件: client.htm, server.htm, status.htm, logs.htm, settings.htm"
	@echo "  - 配置文件: openvpn-admin"
	@echo "  - 脚本文件: generate-client.sh, client-connect-cn.sh, renewcert.sh, clean-garbage.sh"
	@echo "  - 模板文件: server.template"
	@echo "=========================================="
endef

# 在编译后显示信息
Build/Compile: Build/ShowInfo
