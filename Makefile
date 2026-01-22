# 项目根目录 Makefile
# 用于项目整体管理、打包和 GitHub Actions 构建

PKG_NAME := luci-app-openvpn-admin
PKG_VERSION := 1.0.0
PKG_RELEASE := $(shell date +%Y%m%d)

# 默认目标
.PHONY: default help prepare build clean package release

default: help

# 显示帮助信息
help:
	@echo "================================================================================"
	@echo "  OpenVPN 管理插件 - luci-app-openvpn-admin 构建系统"
	@echo "================================================================================"
	@echo ""
	@echo "📦 包信息:"
	@echo "  名称: $(PKG_NAME)"
	@echo "  版本: $(PKG_VERSION)-$(PKG_RELEASE)"
	@echo ""
	@echo "🔨 构建命令:"
	@echo "  make prepare    准备构建目录"
	@echo "  make build      构建所有架构的包 (需要 Docker)"
	@echo "  make clean      清理构建文件"
	@echo "  make package    创建源码打包文件"
	@echo "  make release    准备发布文件"
	@echo ""
	@echo "📂 项目结构:"
	@echo "  ./                            项目根目录"
	@echo "  ├── package/                  OpenWrt 包定义"
	@echo "  │   └── luci-app-openvpn-admin/"
	@echo "  │       └── Makefile          OpenWrt SDK 构建规则"
	@echo "  ├── files/                    安装文件"
	@echo "  └── .github/workflows/        GitHub Actions 配置"
	@echo ""
	@echo "🔧 集成到 OpenWrt 源码:"
	@echo "  1. 复制 package/luci-app-openvpn-admin 到 OpenWrt 的 package 目录"
	@echo "  2. 复制 files 目录到 OpenWrt 源码根目录"
	@echo "  3. 运行: make menuconfig 选择插件"
	@echo "  4. 运行: make package/luci-app-openvpn-admin/compile V=s"
	@echo "================================================================================"

# 准备构建目录
prepare:
	@echo "🛠️  准备构建目录..."
	
	# 清理旧的构建目录
	@if [ -d "build" ]; then \
		echo "清理旧的构建目录..."; \
		rm -rf build; \
	fi
	
	# 创建目录结构
	@echo "创建目录结构..."
	mkdir -p build/package/$(PKG_NAME)
	mkdir -p build/files
	mkdir -p build/.github/workflows
	
	# 复制文件
	@echo "复制文件..."
	cp -r package/* build/package/
	cp -r files/* build/files/
	cp -r .github/workflows/* build/.github/workflows/ 2>/dev/null || true
	
	# 复制其他必要文件
	@echo "复制配置文件..."
	cp README.md build/ 2>/dev/null || true
	cp LICENSE build/ 2>/dev/null || true
	cp .gitattributes build/ 2>/dev/null || true
	cp .gitignore build/ 2>/dev/null || true
	
	@echo "✅ 构建目录准备完成: build/"

# 构建包 (使用 Docker 模拟多架构构建)
build: prepare
	@echo "🔨 开始构建包..."
	@echo ""
	@echo "⚠️  注意: 完整的多架构构建需要使用 GitHub Actions"
	@echo "本地构建仅用于测试，输出为通用架构 (all)"
	@echo ""
	
	# 创建临时构建环境
	mkdir -p build/test-build
	
	# 生成测试用的 IPK 包结构
	@echo "创建测试包结构..."
	mkdir -p build/test-build/CONTROL
	mkdir -p build/test-build/usr/lib/lua/luci
	mkdir -p build/test-build/etc/config
	mkdir -p build/test-build/etc/openvpn-admin
	
	# 生成 control 文件
	cat > build/test-build/CONTROL/control << EOF
Package: $(PKG_NAME)
Version: $(PKG_VERSION)-$(PKG_RELEASE)
Depends: luci-base, openvpn-openssl, luci-lib-jsonc, easy-rsa, curl, openssl-util, netcat-openbsd
Architecture: all
Section: luci
Category: LuCI
Priority: optional
Maintainer: OpenVPN Admin Team <openvpn-admin@example.com>
Description: OpenVPN Management Interface
  A comprehensive OpenVPN management interface for OpenWrt/LEDE/ImmortalWrt.
  Features include client management, certificate generation, connection monitoring,
  and server configuration.
EOF
	
	# 复制示例文件
	@echo "复制示例文件..."
	cp -r build/files/usr/lib/lua/luci/controller build/test-build/usr/lib/lua/luci/ 2>/dev/null || true
	cp -r build/files/usr/lib/lua/luci/view build/test-build/usr/lib/lua/luci/ 2>/dev/null || true
	cp build/files/etc/config/openvpn-admin build/test-build/etc/config/ 2>/dev/null || true
	cp build/files/etc/openvpn-admin/*.sh build/test-build/etc/openvpn-admin/ 2>/dev/null || true
	
	# 创建测试 IPK 包
	@echo "创建测试 IPK 包..."
	cd build && tar czf ../$(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE)-all.ipk -C test-build .
	
	@echo ""
	@echo "✅ 构建完成!"
	@echo "📦 生成的测试包: $(PKG_NAME)-$(PKG_VERSION)-$(PKG_RELEASE)-all.ipk"
	@echo "⚠️  注意: 这是测试包，实际使用请使用 GitHub Actions 构建"

# 清理构建文件
clean:
	@echo "🧹 清理构建文件..."
	
	# 清理构建目录
	@if [ -d "build" ]; then \
		echo "删除 build/ 目录..."; \
		rm -rf build; \
	fi
	
	# 清理测试包
	@if ls $(PKG_NAME)-*.ipk 1> /dev/null 2>&1; then \
		echo "删除测试 IPK 文件..."; \
		rm -f $(PKG_NAME)-*.ipk; \
	fi
	
	# 清理打包文件
	@if ls $(PKG_NAME)-*.tar.gz 1> /dev/null 2>&1; then \
		echo "删除打包文件..."; \
		rm -f $(PKG_NAME)-*.tar.gz; \
	fi
	
	# 清理临时文件
	@echo "删除临时文件..."
	rm -rf tmp/
	rm -rf logs/
	rm -rf output/
	
	@echo "✅ 清理完成!"

# 创建源码打包文件
package: clean prepare
	@echo "📦 创建源码打包文件..."
	
	# 进入构建目录并打包
	cd build && tar czf ../$(PKG_NAME)-$(PKG_VERSION)-src.tar.gz .
	
	@echo ""
	@echo "✅ 源码包创建完成!"
	@echo "📄 文件: $(PKG_NAME)-$(PKG_VERSION)-src.tar.gz"
	@echo ""
	@echo "🔧 使用方法:"
	@echo "  tar xzf $(PKG_NAME)-$(PKG_VERSION)-src.tar.gz"
	@echo "  cd openwrt-sdk/"
	@echo "  # 将 package/luci-app-openvpn-admin 复制到 OpenWrt SDK 的 package 目录"
	@echo "  # 将 files 目录复制到 OpenWrt SDK 根目录"
	@echo "  make package/luci-app-openvpn-admin/compile V=s"

# 准备发布文件
release: package
	@echo "🚀 准备发布文件..."
	
	# 创建发布目录
	mkdir -p release/$(PKG_VERSION)
	
	# 复制文件到发布目录
	cp $(PKG_NAME)-$(PKG_VERSION)-src.tar.gz release/$(PKG_VERSION)/
	cp README.md release/$(PKG_VERSION)/
	cp LICENSE release/$(PKG_VERSION)/
	
	# 创建版本说明
	cat > release/$(PKG_VERSION)/CHANGELOG.md << EOF
# luci-app-openvpn-admin v$(PKG_VERSION)

## 版本信息
- **版本**: $(PKG_VERSION)-$(PKG_RELEASE)
- **发布日期**: $(shell date +%Y-%m-%d)
- **OpenWrt版本**: 21.02 或更高
- **LuCI版本**: 最新

## 功能特性
- OpenVPN 连接状态实时监控
- 客户端配置生成和证书管理
- 服务端配置管理
- 日志查看和过滤
- 客户端黑名单管理
- 多语言支持 (中英文)

## 安装说明
详见 README.md 文件

## 构建说明
详见 package/luci-app-openvpn-admin/Makefile
EOF
	
	@echo ""
	@echo "✅ 发布文件准备完成!"
	@echo "📁 发布目录: release/$(PKG_VERSION)/"
	@echo ""
	@echo "📦 包含文件:"
	@echo "  - $(PKG_NAME)-$(PKG_VERSION)-src.tar.gz (源码包)"
	@echo "  - README.md (使用说明)"
	@echo "  - LICENSE (许可证)"
	@echo "  - CHANGELOG.md (版本日志)"

# 检查项目结构
check:
	@echo "🔍 检查项目结构..."
	
	# 检查必要目录是否存在
	@echo "检查目录结构..."
	
	@if [ ! -d "package/luci-app-openvpn-admin" ]; then \
		echo "❌ 错误: package/luci-app-openvpn-admin 目录不存在"; \
		exit 1; \
	else \
		echo "✅ package/luci-app-openvpn-admin 目录存在"; \
	fi
	
	@if [ ! -f "package/luci-app-openvpn-admin/Makefile" ]; then \
		echo "❌ 错误: package/luci-app-openvpn-admin/Makefile 文件不存在"; \
		exit 1; \
	else \
		echo "✅ package/luci-app-openvpn-admin/Makefile 文件存在"; \
	fi
	
	@if [ ! -d "files" ]; then \
		echo "❌ 错误: files 目录不存在"; \
		exit 1; \
	else \
		echo "✅ files 目录存在"; \
	fi
	
	# 检查必要的文件
	@echo "检查必要文件..."
	
	@if [ ! -f "files/usr/lib/lua/luci/controller/openvpn-admin.lua" ]; then \
		echo "⚠️  警告: 控制器文件不存在"; \
	else \
		echo "✅ 控制器文件存在"; \
	fi
	
	@if [ ! -f "files/etc/config/openvpn-admin" ]; then \
		echo "⚠️  警告: 配置文件不存在"; \
	else \
		echo "✅ 配置文件存在"; \
	fi
	
	@echo ""
	@echo "✅ 项目结构检查完成!"

# 测试安装脚本
test-scripts:
	@echo "🧪 测试脚本文件..."
	
	# 检查脚本文件是否存在
	@if [ -f "files/etc/openvpn-admin/generate-client.sh" ]; then \
		echo "✅ generate-client.sh 存在"; \
		# 检查脚本是否有执行权限（通过文件内容判断）
		if head -1 "files/etc/openvpn-admin/generate-client.sh" | grep -q "^#!/bin/sh"; then \
			echo "✅ generate-client.sh 包含正确的 shebang"; \
		else \
			echo "⚠️  警告: generate-client.sh 缺少 shebang"; \
		fi; \
	else \
		echo "❌ 错误: generate-client.sh 不存在"; \
	fi
	
	@if [ -f "files/etc/openvpn-admin/client-connect-cn.sh" ]; then \
		echo "✅ client-connect-cn.sh 存在"; \
	else \
		echo "⚠️  警告: client-connect-cn.sh 不存在"; \
	fi
	
	@if [ -f "files/etc/openvpn-admin/renewcert.sh" ]; then \
		echo "✅ renewcert.sh 存在"; \
	else \
		echo "⚠️  警告: renewcert.sh 不存在"; \
	fi
	
	@if [ -f "files/etc/openvpn-admin/clean-garbage.sh" ]; then \
		echo "✅ clean-garbage.sh 存在"; \
	else \
		echo "⚠️  警告: clean-garbage.sh 不存在"; \
	fi
	
	@echo ""
	@echo "✅ 脚本文件检查完成!"

# 生成 .gitignore 文件
gitignore:
	@echo "📝 生成 .gitignore 文件..."
	
	cat > .gitignore << EOF
# 构建产物
*.ipk
*.opkg
*.deb
*.rpm
*.tar.gz
*.tar.xz
/bin/
/build/
/openwrt-sdk/
/tmp/
/feeds/

# OpenWrt 构建文件
.config
.config.old
/.config
/.config.old

# 临时文件
*.tmp
*.bak
*.log
*.pid
*.swp
*.swo
*~

# 系统文件
.DS_Store
Thumbs.db
desktop.ini

# IDE/编辑器
.vscode/
.idea/
*.code-workspace
.project
.classpath
.settings/

# 开发环境
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# 日志文件
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# 本地测试文件
local-test/
test-ipk/

# 打包文件
/dist/
/out/
/release/
/packages/

# 文档生成
/docs/_build/
/docs/.build/

# Windows 特定
*.lnk
*.exe
*.dll
*.pdb
*.obj
*.lib

# macOS 特定
._*
.Spotlight-V100
.Trashes

# Linux 特定
*.so
*.o
*.a
*.ko
EOF
	
	@echo "✅ .gitignore 文件生成完成!"

# 验证项目
validate: check test-scripts
	@echo "🎉 项目验证通过!"
	@echo ""
	@echo "📦 项目信息:"
	@echo "  名称: $(PKG_NAME)"
	@echo "  版本: $(PKG_VERSION)-$(PKG_RELEASE)"
	@echo "  架构: all (通用)"
	@echo ""
	@echo "🚀 准备上传到 GitHub:"
	@echo "  git add ."
	@echo "  git commit -m '发布 $(PKG_VERSION)-$(PKG_RELEASE)'"
	@echo "  git tag v$(PKG_VERSION)"
	@echo "  git push origin main --tags"
