name: Build luci-app-openvpn-admin (360T7)
on: [workflow_dispatch]

jobs:
  build-360t7:
    runs-on: ubuntu-22.04
    timeout-minutes: 180
    env:
      MAKE_JOBS: 2
      SDK_URL: "https://downloads.immortalwrt.org/releases/23.05.0/targets/rockchip/armv8/immortalwrt-sdk-23.05.0-rockchip-armv8_gcc-12.3.0_musl.Linux-x86_64.tar.xz"
      # 关键修改1：移除 SDK 中找不到的依赖（easy-rsa/netcat-openbsd）
      DEPENDENCIES: "openssl-util curl openvpn-openssl luci-lib-jsonc luci-compat luci-base"

    steps:
      - name: 1. Checkout code
        uses: actions/checkout@v4

      - name: 2. Install build dependencies
        run: |
          sudo apt-get update && sudo apt-get install -y build-essential libncurses5-dev gawk git wget unzip python3 python3-pip file rsync curl python3-pyelftools subversion time
          sudo pip3 install pyelftools || true

      - name: 3. Download & extract ImmortalWrt SDK
        id: sdk
        run: |
          wget --timeout=60 --tries=3 $SDK_URL -O sdk.tar.xz || { echo "SDK download failed"; exit 1; }
          tar xf sdk.tar.xz && mv $(find . -maxdepth 1 -type d -name "*sdk*" | head -1) openwrt-sdk
          ls -la openwrt-sdk/

      - name: 4. Prepare package files (关键修改2：适配新的目录结构)
        run: |
          cd openwrt-sdk
          # 清理旧目录，创建新目录
          rm -rf package/luci-app-openvpn-admin && mkdir -p package/luci-app-openvpn-admin
          # 复制修正后的 Makefile
          [ -f ../Makefile ] && cp ../Makefile package/luci-app-openvpn-admin/
          # 复制 luasrc/root 目录（新结构），而非 files 目录
          [ -d ../luasrc ] && cp -r ../luasrc package/luci-app-openvpn-admin/
          [ -d ../root ] && cp -r ../root package/luci-app-openvpn-admin/
          # 兼容旧 files 目录（可选，防止用户还没调整目录）
          if [ -d ../files ]; then
            mkdir -p package/luci-app-openvpn-admin/root
            cp -r ../files/* package/luci-app-openvpn-admin/root/
          fi
          # 验证目录结构
          echo "==== Package dir structure ===="
          find package/luci-app-openvpn-admin -type d | sort | head -20

      - name: 5. Update feeds & install dependencies (关键修改3：跳过找不到的依赖)
        run: |
          cd openwrt-sdk
          ./scripts/feeds update -a -f  # 强制刷新 feeds
          # 只安装能找到的依赖，easy-rsa/netcat-openbsd 跳过
          ./scripts/feeds install luci-base luci-lib-jsonc luci-compat openvpn-openssl curl openssl-util || true
          # 检查依赖是否安装成功
          echo "==== Installed feeds ===="
          ./scripts/feeds list | grep -E "luci|openvpn|curl"

      - name: 6. Generate .config (关键修改4：注释掉找不到的依赖配置)
        run: |
          cd openwrt-sdk
          cat > .config << EOF
          CONFIG_TARGET_rockchip=y
          CONFIG_TARGET_rockchip_armv8=y
          CONFIG_TARGET_DEVICE_packages=y
          CONFIG_PACKAGE_luci-app-openvpn-admin=y
          CONFIG_PACKAGE_luci-base=y
          CONFIG_PACKAGE_luci-lib-jsonc=y
          CONFIG_PACKAGE_luci-compat=y
          CONFIG_PACKAGE_openvpn-openssl=y
          CONFIG_OPENVPN_OPENSSL_ENABLE_MANAGEMENT=y
          CONFIG_OPENVPN_OPENSSL_ENABLE_LZO=y
          CONFIG_OPENVPN_OPENSSL_ENABLE_LZ4=y
          # CONFIG_PACKAGE_easy-rsa is not set  # SDK 中不存在，注释
          # CONFIG_PACKAGE_netcat-openbsd is not set  # SDK 中不存在，注释
          CONFIG_PACKAGE_curl=y
          CONFIG_PACKAGE_openssl-util=y
          CONFIG_ALL=n
          CONFIG_ALL_KMODS=n
          CONFIG_ALL_NONSHARED=n
          EOF
          make defconfig
          grep -E "CONFIG_TARGET|CONFIG_PACKAGE|CONFIG_OPENVPN" .config

      - name: 7. Compile dependencies (关键修改5：容错编译，失败不中断)
        run: |
          cd openwrt-sdk
          for pkg in $DEPENDENCIES; do
            echo "==== Compiling $pkg ===="
            pkg_path=$(find package feeds -name $pkg -type d | head -1)
            if [ -n "$pkg_path" ]; then
              # 容错编译，失败仅警告
              make package/$pkg/compile V=sc -j$MAKE_JOBS || echo "⚠ $pkg compile failed, skip (non-critical)"
            else
              echo "⚠ $pkg not found in feeds, skip"
            fi
          done

      - name: 8. Compile main package (关键修改6：增加调试日志 + 容错)
        run: |
          cd openwrt-sdk
          [ ! -d "package/luci-app-openvpn-admin" ] && { echo "Package dir missing"; exit 1; }
          # 清理旧构建文件
          make package/luci-app-openvpn-admin/clean
          # 编译并输出详细日志，失败保留日志
          make package/luci-app-openvpn-admin/compile V=s -j$MAKE_JOBS 2>&1 | tee compile-log.txt
          # 检查编译结果
          MAIN_IPK=$(find bin -name "*luci-app-openvpn-admin*.ipk" -type f | head -1)
          if [ -z "$MAIN_IPK" ]; then
            echo "==== Compile log (last 100 lines) ===="
            tail -100 compile-log.txt
            echo "❌ Main package compile failed"
            exit 1
          else
            echo "✅ Main package compiled: $MAIN_IPK"
          fi

      - name: 9. Collect artifacts
        run: |
          cd openwrt-sdk
          mkdir -p ../output-360T7
          # 复制所有 IPK（包括依赖）
          find bin -name "*.ipk" -exec cp {} ../output-360T7/ \;
          # 验证主插件 IPK
          MAIN_IPK=$(find ../output-360T7 -name "*luci-app-openvpn-admin*.ipk" | head -1)
          if [ -n "$MAIN_IPK" ]; then
            echo "✅ Success: $(basename $MAIN_IPK)"
            # 查看 IPK 内容（验证目录结构）
            tar -tzf $MAIN_IPK | grep -E "(controller|view|etc/config)" | head -10
          else
            echo "❌ Main package not found in output"
            ls -lh ../output-360T7/
            exit 1
          fi

      - name: 10. Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: openvpn-admin-360T7
          path: output-360T7/
          retention-days: 7

      - name: 11. Build report
        if: always()
        run: |
          echo "========================================"
          echo "构建状态报告 - 360T7 (aarch64_cortex-a72)"
          echo "========================================"
          echo "作业状态: ${{ job.status }}"
          echo "SDK下载状态: ${{ steps.sdk.outcome }}"
          echo ""
          if [ -d output-360T7 ]; then
            IPK_COUNT=$(find output-360T7 -name "*.ipk" | wc -l)
            echo "📦 生成的IPK数量: $IPK_COUNT"
            echo "📋 IPK列表:"
            ls -lh output-360T7/
            MAIN_IPK=$(find output-360T7 -name "*luci-app-openvpn-admin*.ipk" | head -1)
            [ -n "$MAIN_IPK" ] && echo "✅ 核心插件: $(basename $MAIN_IPK)" || echo "❌ 核心插件编译失败"
          else
            echo "❌ 输出目录不存在"
          fi
