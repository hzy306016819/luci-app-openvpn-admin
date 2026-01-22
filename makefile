include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-openvpn-admin
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

PKG_BUILD_DIR:=$(BUILD_DIR)/$(PKG_NAME)-$(PKG_VERSION)

include $(INCLUDE_DIR)/package.mk

define Package/$(PKG_NAME)
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=OpenVPN Management Interface
  PKGARCH:=all
  DEPENDS:=+luci-base +openvpn-openssl +luci-lib-jsonc +easy-rsa +curl +openssl-util +netcat
endef

define Package/$(PKG_NAME)/description
  一个完整的OpenVPN管理界面，包含状态监控、客户端管理、服务端配置、日志查看和设置功能。
  支持基于CN的黑名单管理、客户端证书生成、实时连接监控等。
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
endef

define Build/Configure
endef

define Build/Compile
endef

define Package/$(PKG_NAME)/install
	# Install LuCI controller
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/controller
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/controller/openvpn-admin.lua \
		$(1)/usr/lib/lua/luci/controller/
	
	# Install LuCI views
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci/view/openvpn-admin
	$(INSTALL_DATA) ./files/usr/lib/lua/luci/view/openvpn-admin/*.htm \
		$(1)/usr/lib/lua/luci/view/openvpn-admin/
	
	# Install UCI configuration
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DATA) ./files/etc/config/openvpn-admin \
		$(1)/etc/config/
	
	# Install scripts
	$(INSTALL_DIR) $(1)/etc/openvpn-admin
	$(INSTALL_BIN) ./files/etc/openvpn-admin/generate-client.sh \
		$(1)/etc/openvpn-admin/
	$(INSTALL_BIN) ./files/etc/openvpn-admin/client-connect-cn.sh \
		$(1)/etc/openvpn-admin/
	$(INSTALL_BIN) ./files/etc/openvpn-admin/clean-garbage.sh \
		$(1)/etc/openvpn-admin/
	$(INSTALL_BIN) ./files/etc/openvpn-admin/renewcert.sh \
		$(1)/etc/openvpn-admin/
	
	# Create necessary directories
	$(INSTALL_DIR) $(1)/etc/openvpn-admin/template
	echo "config openvpn 'myvpn'" > $(1)/etc/openvpn-admin/template/server.template
	echo "    option enabled '1'" >> $(1)/etc/openvpn-admin/template/server.template
	echo "    option port '1194'" >> $(1)/etc/openvpn-admin/template/server.template
	echo "    option proto 'udp'" >> $(1)/etc/openvpn-admin/template/server.template
	
	# Create initial directories for runtime
	$(INSTALL_DIR) $(1)/tmp/openvpn-admin
	
	# Install post-install script
	$(INSTALL_DIR) $(1)/etc/uci-defaults
	echo '#!/bin/sh' > $(1)/etc/uci-defaults/99-luci-openvpn-admin
	echo '# Create necessary directories' >> $(1)/etc/uci-defaults/99-luci-openvpn-admin
	echo 'mkdir -p /etc/openvpn-admin/template 2>/dev/null' >> $(1)/etc/uci-defaults/99-luci-openvpn-admin
	echo 'mkdir -p /tmp/openvpn-admin 2>/dev/null' >> $(1)/etc/uci-defaults/99-luci-openvpn-admin
	echo 'mkdir -p /etc/openvpn/pki 2>/dev/null' >> $(1)/etc/uci-defaults/99-luci-openvpn-admin
	echo 'chmod 755 /etc/openvpn-admin/*.sh 2>/dev/null' >> $(1)/etc/uci-defaults/99-luci-openvpn-admin
	echo 'chmod 755 /tmp/openvpn-admin 2>/dev/null' >> $(1)/etc/uci-defaults/99-luci-openvpn-admin
	chmod 755 $(1)/etc/uci-defaults/99-luci-openvpn-admin
endef

define Package/$(PKG_NAME)/postinst
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	# Ensure directories exist
	mkdir -p /etc/openvpn-admin/template 2>/dev/null
	mkdir -p /tmp/openvpn-admin 2>/dev/null
	mkdir -p /etc/openvpn/pki 2>/dev/null
	
	# Set permissions
	chmod 755 /etc/openvpn-admin/*.sh 2>/dev/null || true
	chmod 755 /tmp/openvpn-admin 2>/dev/null || true
	
	# Reload uhttpd
	/etc/init.d/uhttpd restart >/dev/null 2>&1 || true
	
	# Initial setup for openvpn-admin
	if [ ! -f /etc/openvpn-admin/initialized ]; then
		# Initialize default configuration if not exists
		if ! uci -q get openvpn-admin.@settings[0] >/dev/null; then
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
		fi
		touch /etc/openvpn-admin/initialized
	fi
	
	# Restart services
	/etc/init.d/uhttpd reload >/dev/null 2>&1
	/etc/init.d/rpcd reload >/dev/null 2>&1
fi
exit 0
endef

define Package/$(PKG_NAME)/prerm
#!/bin/sh
if [ -z "$${IPKG_INSTROOT}" ]; then
	# Nothing to do before removal
	true
fi
exit 0
endef

$(eval $(call BuildPackage,$(PKG_NAME)))
