# luci-app-openvpn-admin 项目构建脚本
# 作者: [hzy306016819]
# 版本: 1.0.0
# 描述: 用于管理 OpenVPN 管理插件项目，包含打包、清理等任务

PKG_NAME := luci-app-openvpn-admin
PKG_VERSION := 1.0.0
PKG_RELEASE := $(shell date +%Y%m%d)

# 默认目标
.DEFAULT_GOAL := help

# 显示帮助信息
.PHONY: help
help:
	@echo "===================================================================="
	@echo "  luci-app-openvpn-admin 项目构建系统"
	@echo "===================================================================="
	@echo ""
	@echo "  项目信息:"
	@echo "    名称: $(PKG_NAME)"
	@echo "    版本: $(PKG_VERSION)-$(PKG_RELEASE)"
	@echo ""
	@echo "  可用命令:"
	@echo ""
	@echo "  项目构建:"
	@echo "    make prepare      - 准备构建目录结构"
	@echo "    make package      - 创建发布包 (.tar.gz)"
	@echo "    make clean        - 清理构建文件"
	@echo "    make distclean    - 完全清理（包括下载的SDK）"
	@echo ""
	@echo "  测试命令:"
	@echo "    make check-files  - 检查项目文件完整性"
	@echo "    make list-files   - 列出所有项目文件"
	@echo "    make permissions  - 修复文件权限"
	@echo ""
	@echo "  发布命令:"
	@echo "    make release      - 创建完整发布包"
	@echo "    make upload-test  - 模拟上传到测试环境"
	@echo ""
	@echo "  集成说明:"
	@echo "    ============================================="
	@echo "    要集成到 OpenWrt 固件，请按以下步骤操作:"
	@echo "    1. 复制 package/luci-app-openvpn-admin 目录到"
	@echo "       OpenWrt 源码的 package/ 目录下"
	@echo "    2. 复制 files/ 目录到 OpenWrt 源码根目录"
	@echo "    3. 运行: make menuconfig"
	@echo "       进入 LuCI → Applications"
	@echo "       选择 luci-app-openvpn-admin"
	@echo "    4. 运行: make package/luci-app-openvpn-admin/compile V=s"
	@echo "    ============================================="
	@echo ""

# 准备构建目录
.PHONY: prepare
prepare:
	@echo "🔄 准备构建目录..."
	@echo "  创建目录结构..."
	mkdir -p build/package/$(PKG_NAME)
	mkdir -p build/files/etc/openvpn-admin/template
	mkdir -p build/files/usr/lib/lua/luci/controller
	mkdir -p build/files/usr/lib/lua/luci/view/openvpn-admin
	
	@echo "  复制项目文件..."
	# 复制主控制器
	if [ -f "files/usr/lib/lua/luci/controller/openvpn-admin.lua" ]; then \
		cp "files/usr/lib/lua/luci/controller/openvpn-admin.lua" \
		   "build/files/usr/lib/lua/luci/controller/"; \
		echo "    ✓ 复制控制器: openvpn-admin.lua"; \
	else \
		echo "    ✗ 错误: 找不到控制器文件"; \
		exit 1; \
	fi
	
	# 复制视图文件
	@if [ -d "files/usr/lib/lua/luci/view/openvpn-admin" ]; then \
		count=$$(ls -1 "files/usr/lib/lua/luci/view/openvpn-admin/" 2>/dev/null | wc -l); \
		if [ $$count -gt 0 ]; then \
			cp "files/usr/lib/lua/luci/view/openvpn-admin/"*.htm \
			   "build/files/usr/lib/lua/luci/view/openvpn-admin/" 2>/dev/null || true; \
			echo "    ✓ 复制视图文件 ($$count 个)"; \
		else \
			echo "    ⚠ 警告: 视图目录为空"; \
		fi \
	else \
		echo "    ⚠ 警告: 视图目录不存在"; \
	fi
	
	# 复制配置文件
	if [ -f "files/etc/config/openvpn-admin" ]; then \
		cp "files/etc/config/openvpn-admin" "build/files/etc/config/"; \
		echo "    ✓ 复制配置文件: openvpn-admin"; \
	else \
		echo "    ✗ 错误: 找不到配置文件"; \
		exit 1; \
	fi
	
	# 复制脚本文件
	@echo "  复制脚本文件..."
	@if [ -d "files/etc/openvpn-admin" ]; then \
		cp "files/etc/openvpn-admin/"*.sh "build/files/etc/openvpn-admin/" 2>/dev/null || true; \
		chmod +x "build/files/etc/openvpn-admin/"*.sh 2>/dev/null || true; \
		script_count=$$(ls -1 "build/files/etc/openvpn-admin/"*.sh 2>/dev/null | wc -l); \
		echo "    ✓ 复制脚本文件 ($$script_count 个)"; \
	else \
		echo "    ⚠ 警告: 脚本目录不存在"; \
	fi
	
	# 复制模板文件
	@if [ -f "files/etc/openvpn-admin/template/server.template" ]; then \
		cp "files/etc/openvpn-admin/template/server.template" \
		   "build/files/etc/openvpn-admin/template/"; \
		echo "    ✓ 复制模板文件: server.template"; \
	else \
		echo "    ⚠ 警告: 模板文件不存在"; \
	fi
	
	# 复制包 Makefile
	if [ -f "package/luci-app-openvpn-admin/Makefile" ]; then \
		cp "package/luci-app-openvpn-admin/Makefile" \
		   "build/package/luci-app-openvpn-admin/"; \
		echo "    ✓ 复制包 Makefile"; \
	else \
		echo "    ✗ 错误: 找不到包 Makefile"; \
		exit 1; \
	fi
	
	@echo "✅ 构建目录准备完成！"
	@echo "   目录: build/"
	@echo "   大小: $$(du -sh build/ | cut -f1)"
	@echo ""

# 检查文件完整性
.PHONY: check-files
check-files:
	@echo "🔍 检查项目文件完整性..."
	@echo ""
	
	@echo "1. 检查必需文件:"
	required_files="\
		files/usr/lib/lua/luci/controller/openvpn-admin.lua \
		files/etc/config/openvpn-admin \
		package/luci-app-openvpn-admin/Makefile"
	
	for file in $$required_files; do \
		if [ -f "$$file" ]; then \
			echo "    ✓ $$file"; \
		else \
			echo "    ✗ 缺少: $$file"; \
			exit 1; \
		fi \
	done
	
	@echo ""
	@echo "2. 检查视图文件:"
	if [ -d "files/usr/lib/lua/luci/view/openvpn-admin" ]; then \
		htm_count=$$(ls -1 "files/usr/lib/lua/luci/view/openvpn-admin/"*.htm 2>/dev/null | wc -l); \
		if [ $$htm_count -eq 5 ]; then \
			echo "    ✓ 视图文件完整 (5个HTM文件)"; \
		else \
			echo "    ⚠ 视图文件数量: $$htm_count (预期: 5)"; \
			ls -la "files/usr/lib/lua/luci/view/openvpn-admin/"*.htm 2>/dev/null || true; \
		fi \
	else \
		echo "    ✗ 视图目录不存在"; \
	fi
	
	@echo ""
	@echo "3. 检查脚本文件:"
	if [ -d "files/etc/openvpn-admin" ]; then \
		script_count=$$(ls -1 "files/etc/openvpn-admin/"*.sh 2>/dev/null | wc -l); \
		if [ $$script_count -ge 4 ]; then \
			echo "    ✓ 脚本文件完整 (至少4个脚本)"; \
		else \
			echo "    ⚠ 脚本文件数量: $$script_count (预期: ≥4)"; \
		fi \
	else \
		echo "    ✗ 脚本目录不存在"; \
	fi
	
	@echo ""
	@echo "✅ 文件检查完成"

# 列出所有项目文件
.PHONY: list-files
list-files:
	@echo "📁 项目文件列表:"
	@echo ""
	
	@echo "控制器文件:"
	@find files/usr/lib/lua/luci/controller -type f -name "*.lua" 2>/dev/null | \
		while read file; do \
			echo "  $$file ($$(wc -l < "$$file") 行)"; \
		done
	
	@echo ""
	@echo "视图文件:"
	@find files/usr/lib/lua/luci/view/openvpn-admin -type f -name "*.htm" 2>/dev/null | \
		while read file; do \
			echo "  $$file ($$(wc -l < "$$file") 行)"; \
		done
	
	@echo ""
	@echo "配置文件:"
	@find files/etc/config -type f 2>/dev/null | \
		while read file; do \
			echo "  $$file ($$(wc -l < "$$file") 行)"; \
		done
	
	@echo ""
	@echo "脚本文件:"
	@find files/etc/openvpn-admin -type f -name "*.sh" 2>/dev/null | \
		while read file; do \
			perm=$$(ls -l "$$file" | cut -c1-10); \
			echo "  $$perm $$file ($$(wc -l < "$$file") 行)"; \
		done
	
	@echo ""
	@echo "模板文件:"
	@find files/etc/openvpn-admin/template -type f 2>/dev/null | \
		while read file; do \
			echo "  $$file ($$(wc -l < "$$file") 行)"; \
		done
	
	@echo ""
	@echo "构建文件:"
	@find package -name "Makefile" -type f 2>/dev/null | \
		while read file; do \
			echo "  $$file ($$(wc -l < "$$file") 行)"; \
		done

# 修复文件权限
.PHONY: permissions
permissions:
	@echo "🔧 修复文件权限..."
	
	@echo "  设置脚本文件执行权限..."
	chmod +x files/etc/openvpn-admin/*.sh 2>/dev/null || true
	
	@echo "  检查文件换行符..."
	@for file in $$(find . -name "*.lua" -o -name "*.sh" -o -name "*.htm" -o -name "Makefile" -type f); do \
		if file "$$file" | grep -q "CRLF"; then \
			echo "    ⚠ $$file 有 CRLF 换行符"; \
		fi \
	done
	
	@echo "✅ 权限修复完成"

# 创建发布包
.PHONY: package
package: prepare
	@echo "📦 创建发布包..."
	
	# 检查是否已准备构建目录
	if [ ! -d "build" ]; then \
		echo "  错误: 请先运行 'make prepare'"; \
		exit 1; \
	fi
	
	# 创建版本文件
	echo "$(PKG_VERSION)-$(PKG_RELEASE)" > "build/VERSION"
	echo "构建时间: $$(date)" >> "build/VERSION"
	echo "Git提交: $$(git rev-parse --short HEAD 2>/dev/null || echo '未知')" >> "build/VERSION"
	
	# 创建压缩包
	cd build && tar czf "../$(PKG_NAME)-$(PKG_VERSION).tar.gz" .
	
	# 计算文件大小
	filesize=$$(du -h "$(PKG_NAME)-$(PKG_VERSION).tar.gz" | cut -f1)
	
	@echo "✅ 发布包创建完成！"
	@echo "   文件: $(PKG_NAME)-$(PKG_VERSION).tar.gz"
	@echo "   大小: $$filesize"
	@echo "   包含:"
	@echo "     - package/luci-app-openvpn-admin/Makefile"
	@echo "     - files/ 目录下的所有文件"
	@echo "     - VERSION 文件"
	@echo ""

# 创建完整发布版本
.PHONY: release
release: check-files package
	@echo "🚀 创建完整发布版本..."
	
	# 生成 MD5 校验和
	md5sum "$(PKG_NAME)-$(PKG_VERSION).tar.gz" > "$(PKG_NAME)-$(PKG_VERSION).tar.gz.md5"
	
	# 生成 SHA256 校验和
	sha256sum "$(PKG_NAME)-$(PKG_VERSION).tar.gz" > "$(PKG_NAME)-$(PKG_VERSION).tar.gz.sha256"
	
	# 创建发布说明
	cat > "RELEASE-$(PKG_VERSION).md" << EOF
# luci-app-openvpn-admin v$(PKG_VERSION)

## 构建信息
- **版本**: $(PKG_VERSION)-$(PKG_RELEASE)
- **构建时间**: $$(date)
- **Git提交**: $$(git rev-parse --short HEAD 2>/dev/null || echo '未知')

## 文件列表
\`\`\`
$$(tar -tzf "$(PKG_NAME)-$(PKG_VERSION).tar.gz" | sort)
\`\`\`

## 安装说明
1. 解压压缩包：
   \`\`\`bash
   tar xzf $(PKG_NAME)-$(PKG_VERSION).tar.gz
   \`\`\`

2. 集成到 OpenWrt：
   \`\`\`bash
   # 复制包定义
   cp -r package/luci-app-openvpn-admin /path/to/openwrt/package/
   # 复制文件
   cp -r files /path/to/openwrt/
   \`\`\`

3. 编译：
   \`\`\`bash
   make package/luci-app-openvpn-admin/compile V=s
   \`\`\`

## 校验和
- **MD5**: $$(md5sum "$(PKG_NAME)-$(PKG_VERSION).tar.gz" | cut -d' ' -f1)
- **SHA256**: $$(sha256sum "$(PKG_NAME)-$(PKG_VERSION).tar.gz" | cut -d' ' -f1)
EOF
	
	@echo "✅ 完整发布版本创建完成！"
	@echo "   主文件: $(PKG_NAME)-$(PKG_VERSION).tar.gz"
	@echo "   校验文件:"
	@echo "     - $(PKG_NAME)-$(PKG_VERSION).tar.gz.md5"
	@echo "     - $(PKG_NAME)-$(PKG_VERSION).tar.gz.sha256"
	@echo "   发布说明: RELEASE-$(PKG_VERSION).md"
	@echo ""

# 模拟上传到测试环境
.PHONY: upload-test
upload-test: release
	@echo "📤 模拟上传到测试环境..."
	
	@echo "  检查包结构..."
	if tar -tzf "$(PKG_NAME)-$(PKG_VERSION).tar.gz" | grep -q "package/luci-app-openvpn-admin/Makefile"; then \
		echo "    ✓ 包 Makefile 存在"; \
	else \
		echo "    ✗ 包 Makefile 不存在"; \
		exit 1; \
	fi
	
	@echo "  模拟解压测试..."
	mkdir -p test-install
	cd test-install && tar xzf "../$(PKG_NAME)-$(PKG_VERSION).tar.gz"
	
	@echo "  验证目录结构..."
	if [ -f "test-install/package/luci-app-openvpn-admin/Makefile" ]; then \
		echo "    ✓ 包 Makefile 验证通过"; \
	else \
		echo "    ✗ 包 Makefile 验证失败"; \
		exit 1; \
	fi
	
	if [ -f "test-install/files/usr/lib/lua/luci/controller/openvpn-admin.lua" ]; then \
		echo "    ✓ 控制器文件验证通过"; \
	else \
		echo "    ✗ 控制器文件验证失败"; \
		exit 1; \
	fi
	
	@echo "  清理测试目录..."
	rm -rf test-install
	
	@echo "✅ 上传测试完成！包结构正确"

# 清理构建文件
.PHONY: clean
clean:
	@echo "🧹 清理构建文件..."
	
	if [ -d "build" ]; then \
		echo "  删除 build/ 目录..."; \
		rm -rf build; \
	fi
	
	if [ -d "test-install" ]; then \
		echo "  删除 test-install/ 目录..."; \
		rm -rf test-install; \
	fi
	
	@echo "✅ 构建文件清理完成"

# 完全清理
.PHONY: distclean
distclean: clean
	@echo "🧹 完全清理..."
	
	# 删除发布文件
	rm -f $(PKG_NAME)-*.tar.gz
	rm -f $(PKG_NAME)-*.tar.gz.md5
	rm -f $(PKG_NAME)-*.tar.gz.sha256
	rm -f RELEASE-*.md
	
	# 删除临时文件
	find . -name "*.tmp" -o -name "*.bak" -o -name "*.swp" -o -name "*.swo" | xargs rm -f 2>/dev/null || true
	
	@echo "✅ 完全清理完成"
	@echo "   所有构建和发布文件已删除"

# 显示版本信息
.PHONY: version
version:
	@echo "luci-app-openvpn-admin v$(PKG_VERSION)-$(PKG_RELEASE)"
	@echo "构建系统: $$(uname -s) $$(uname -r)"
	@echo "Git状态: $$(git status --short 2>/dev/null | wc -l || echo '0') 个未提交更改"
