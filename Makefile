# OpenWrt/LEDE/ImmortalWrt 包构建 Makefile
# 作者: [hzy306016819]
# 版本: 1.0.0
# 描述: OpenVPN 管理插件包定义，用于 OpenWrt 构建系统

include $(TOPDIR)/rules.mk

# 包信息
PKG_NAME:=luci-app-openvpn-admin
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

# OpenWrt 构建目录
PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

# 包含 OpenWrt 包宏
include $(INCLUDE_DIR)/package.mk

# 定义 LuCI 包宏
include $(TOPDIR)/feeds/luci/luci.mk

# 包定义
define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=OpenVPN Management Interface
  URL:=https://github.com/hzy306016819/luci-app-openvpn-admin
  PKGARCH:=all
  # 依赖关系（注释 SDK 中找不到的依赖）
  DEPENDS:= \
    +luci-base \
    +openvpn-openssl \
    +luci-lib-jsonc \
    +curl \
    +openssl-util \
    +luci-compat
endef

# 包描述
define Package/$(PKG_NAME)/description
  A comprehensive OpenVPN management interface for OpenWrt/LEDE/ImmortalWrt.
  
  Features include:
  - Real-time connection monitoring
  - Client configuration generation
  - Server configuration management
  - Client blacklist (based on CN)
  - Certificate management
  - Live traffic statistics
  - Log viewer with filtering
  
  一个功能完整的 OpenVPN 管理界面，包含：
  - 实时连接监控
  - 客户端配置生成
  - 服务器配置管理
  - 客户端黑名单（基于CN）
  - 证书管理
  - 实时流量统计
  - 带过滤功能的日志查看器
endef

# 构建准备阶段
define Build/Prepare
	# 创建构建目录
	mkdir -p $(PKG_BUILD_DIR)
	
	# 复制所有文件到构建目录（适配 LuCI 标准结构）
	$(CP) ./luasrc $(PKG_BUILD_DIR)/
	$(CP) ./root $(PKG_BUILD_DIR)/ 2>/dev/null || true
	
	# 兼容旧 files 目录（可选）
	if [ -d ./files ]; then
		mkdir -p $(PKG_BUILD_DIR)/root
		$(CP) ./files/* $(PKG_BUILD_DIR)/root/
	fi
	
	# 确保脚本有执行权限
	chmod +x $(PKG_BUILD_DIR)/root/etc/openvpn-admin/*.sh 2>/dev/null || true
endef

# 构建配置阶段
define Build/Configure
	# 不需要配置
endef

# 构建编译阶段
define Build/Compile
	# LuCI 应用不需要编译
endef

# 安装到目标文件系统
define Package/$(PKG_NAME)/install
	# 安装 LuCI 控制器
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/luasrc/controller/openvpn-admin.lua \
		$(1)/usr/lib/lua/luci/controller/openvpn-admin.lua
	
	# 安装 LuCI 视图文件
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/openvpn-admin
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/luasrc/view/openvpn-admin/*.htm \
		$(1)/usr/lib/lua/luci/view/openvpn-admin/
	
	# 安装配置文件和脚本
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/root/etc/config/openvpn-admin \
		$(1)/etc/config/openvpn-admin
	
	$(INSTALL_DIR) $(1)/etc/openvpn-admin
	$(INSTALL_DIR) $(1)/etc/openvpn-admin/template
	$(INSTALL_BIN) $(PKG_BUILD_DIR)/root/etc/openvpn-admin/*.sh \
		$(1)/etc/openvpn-admin/
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/root/etc/openvpn-admin/template/server.template \
		$(1)/etc/openvpn-admin/template/
	
	# 创建运行时目录
	$(INSTALL_DIR) $(1)/tmp/openvpn-admin
	$(INSTALL_DIR) $(1)/etc/openvpn/pki
	
	# 创建初始配置文件（如果模板不存在）
	if [ ! -f $(PKG_BUILD_DIR)/root/etc/openvpn-admin/template/server.template ]; then \
		mkdir -p $(1)/etc/openvpn-admin/template; \
		echo "config openvpn 'myvpn'" > $(1)/etc/openvpn-admin/template/server.template; \
		echo "    option enabled '1'" >> $(1)/etc/openvpn-admin/template/server.template; \
		echo "    option port '1194'" >> $(1)/etc/openvpn-admin/template/server.template; \
		echo "    option proto 'udp'" >> $(1)/etc/openvpn-admin/template/server.template; \
		echo "    option dev 'tun'" >> $(1)/etc/openvpn-admin/template/server.template; \
		echo "    option management '127.0.0.1 7505'" >> $(1)/etc/openvpn-admin/template/server.template; \
	fi
	
	# 创建空的历史和黑名单文件
	echo '[]' > $(1)/etc/openvpn-admin/openvpn_connection_history.json
	echo '{"version": 1, "entries": []}' > $(1)/etc/openvpn-admin/blacklist.json
	
	# 设置目录权限
	chmod 755 $(1)/etc/openvpn-admin
	chmod 755 $(1)/tmp/openvpn-admin
	chmod 755 $(1)/etc/openvpn/pki
endef

# 后安装脚本
define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "=========================================="
	echo "  OpenVPN 管理插件安装完成！"
	echo "=========================================="
	echo ""
	
	mkdir -p /etc/openvpn-admin/template 2>/dev/null
	mkdir -p /tmp/openvpn-admin 2>/dev/null
	mkdir -p /etc/openvpn/pki 2>/dev/null
	
	chmod 755 /etc/openvpn-admin/*.sh 2>/dev/null || true
	
	if ! uci -q get openvpn-admin.@settings[0] >/dev/null 2>&1; then
		echo "初始化插件配置..."
		
		uci batch << 'EOF'
set openvpn-admin.settings=settings
set openvpn-admin.settings.openvpn_instance='myvpn'
set openvpn-admin.settings.openvpn_config_path='/etc/config/openvpn'
set openvpn-admin.settings.refresh_enabled='1'
set openvpn-admin.settings.refresh_interval='1'
set openvpn-admin.settings.history_size='20'
set openvpn-admin.settings.blacklist_enabled='1'
set openvpn-admin.settings.blacklist_duration='300'
set openvpn-admin.settings.blacklist_file='/etc/openvpn-admin/blacklist.json'
set openvpn-admin.settings.log_file='/tmp/openvpn.log'
set openvpn-admin.settings.history_file='/etc/openvpn-admin/openvpn_connection_history.json'
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
		
		echo "插件配置初始化完成。"
	fi
	
	if ! opkg list-installed | grep -q easy-rsa; then
		echo "⚠ 警告: EasyRSA 未安装，建议执行：opkg install easy-rsa"
	fi
	if ! opkg list-installed | grep -q netcat-openbsd; then
		echo "⚠ 警告: netcat-openbsd 未安装，建议执行：opkg install netcat-openbsd"
	fi
	
	if [ -f "/etc/init.d/openvpn" ]; then
		echo "检测到 OpenVPN 服务。"
	else
		echo "⚠ 警告: OpenVPN 服务未安装，建议执行：opkg install openvpn-openssl"
	fi
	
	/etc/init.d/uhttpd reload >/dev/null 2>&1 || true
	/etc/init.d/rpcd reload >/dev/null 2>&1 || true
	
	echo ""
	echo "访问地址: LuCI → VPN → OpenVPN 管理"
	echo ""
	echo "首次使用建议:"
	echo "  1. 检查设置页面，确保配置正确"
	echo "  2. 在客户端页面生成第一个客户端配置"
	echo "  3. 在状态页面查看连接状态"
	echo ""
fi
exit 0
endef

# 预删除脚本
define Package/$(PKG_NAME)/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "正在卸载 OpenVPN 管理插件..."
	
	if [ -f "/etc/crontabs/root" ]; then
		echo "清理 cron 任务..."
		sed -i '/openvpn-admin/d' /etc/crontabs/root 2>/dev/null || true
		/etc/init.d/cron restart 2>/dev/null || true
	fi
	
	echo "插件卸载准备完成。"
fi
exit 0
endef

# 后删除脚本
define Package/$(PKG_NAME)/postrm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	echo "OpenVPN 管理插件已卸载。"
	
	/etc/init.d/uhttpd reload >/dev/null 2>&1 || true
fi
exit 0
endef

# 关键新增：显式定义 clean 规则（解决 clean 失败问题）
define Package/$(PKG_NAME)/clean
	rm -rf $(PKG_BUILD_DIR)
	rm -rf $(BUILD_DIR)/$(PKG_NAME)
	rm -rf $(BUILD_DIR)/.pkgdir/$(PKG_NAME)
	rm -rf $(STAGING_DIR)/stamp/.$(PKG_NAME)_*
	rm -f $(BIN_DIR)/packages/*/$(PKG_NAME)*.ipk
endef

# 覆盖默认 clean 目标
define Build/Clean
	$(call Package/$(PKG_NAME)/clean)
endef

# 调用 OpenWrt 包构建宏
$(eval $(call BuildPackage,$(PKG_NAME)))

# 构建信息（调试用）
define Build/ShowInfo
	@echo "=========================================="
	@echo "  构建信息: $(PKG_NAME)"
	@echo "=========================================="
	@echo "  版本: $(PKG_VERSION)-$(PKG_RELEASE)"
	@echo "  构建目录: $(PKG_BUILD_DIR)"
	@echo "  依赖包: $(DEPENDS)"
	@echo "=========================================="
endef
