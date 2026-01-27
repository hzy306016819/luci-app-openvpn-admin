# Copyright (C) 2016 Openwrt.org
#
# This is free software, licensed under the Apache License, Version 2.0 .
#

include $(TOPDIR)/rules.mk

LUCI_TITLE:=LuCI support for OpenVPN Admin
LUCI_DEPENDS:=+luci-compat +openvpn-openssl +openvpn-easy-rsa +kmod-tun +netcat +jq +bash +openssl-util

PKG_NAME:=luci-app-openvpn-admin
PKG_VERSION:=3.0
PKG_RELEASE:=0

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature
