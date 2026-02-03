-- OpenVPN管理控制器
-- 项目已更名为luci-app-openvpn-admin
module("luci.controller.openvpn-admin", package.seeall)

local require = require
local http = require("luci.http")
local sys = require("luci.sys")
local util = require("luci.util")
local json = require("luci.jsonc")
local uci = require("luci.model.uci").cursor()
local nixio = require("nixio")

-- 全局配置缓存
local admin_config = nil

-- 获取管理配置（带缓存）
function get_admin_config()
    if admin_config then
        return admin_config
    end
    
    -- 统一配置默认值
    admin_config = {
        openvpn_instance = "myvpn",
        openvpn_config_path = "/etc/config/openvpn",
        refresh_enabled = true,
        refresh_interval = 1,
        history_size = 20,
        blacklist_enabled = true,
        blacklist_duration = 300,
        log_file = "/tmp/openvpn.log",
        history_file = "/etc/openvpn/openvpn_connection_history.json",
        blacklist_file = "/etc/openvpn/blacklist.json",
        easyrsa_dir = "/etc/easy-rsa",
        easyrsa_pki = "/etc/easy-rsa/pki",
        openvpn_pki = "/etc/openvpn/pki",
        
        -- 日志页面配置
        logs_refresh_enabled = true,
        logs_refresh_interval = 10,
        logs_display_lines = 1000,
        
        -- 脚本路径配置
        generate_client_script = "/etc/openvpn/generate-client.sh",
        renew_cert_script = "/etc/openvpn/renewcert.sh",
        
        -- 配置项
        temp_dir = "/tmp/openvpn-admin",
        clean_garbage_enabled = true,
        clean_garbage_time = "4:50",
        clean_garbage_script = "/etc/openvpn/clean-garbage.sh",
        
        -- 新增hotplug配置
        hotplug_enabled = false,
        hotplug_interface = "",
        hotplug_ipv6_address = "",
        hotplug_script_path = "/etc/openvpn/openvpn_hotplug.sh",
        
        -- IPv6脚本配置
        ipv6_script_path = "/etc/openvpn/openvpn_ipv6",
        ipv6_script_interval = 10,  -- 默认10分钟
        ipv6_script_enabled = false -- 默认禁用
    }
    
    -- 尝试从uci配置中读取
    local uci_section = uci:get_first("openvpn-admin", "settings")
    
    if uci_section then
        local configs = {
            "openvpn_instance", "openvpn_config_path", "refresh_enabled", 
            "refresh_interval", "history_size", "blacklist_enabled", 
            "blacklist_duration", "log_file", "history_file", "blacklist_file",
            "easyrsa_dir", "easyrsa_pki", "openvpn_pki",
            "logs_refresh_enabled", "logs_refresh_interval", "logs_display_lines",
            "generate_client_script", "renew_cert_script",
            -- 新增配置项
            "temp_dir", "clean_garbage_enabled", "clean_garbage_time",
            "clean_garbage_script",
            -- IPv6脚本配置
            "ipv6_script_path", "ipv6_script_interval", "ipv6_script_enabled",
            -- 新增hotplug配置项
            "hotplug_enabled", "hotplug_interface", "hotplug_ipv6_address",
            "hotplug_script_path"
        }
        
        for _, key in ipairs(configs) do
    local value = uci:get("openvpn-admin", uci_section, key)
    if value then
        if key == "refresh_enabled" or key == "blacklist_enabled" or 
           key == "logs_refresh_enabled" or key == "clean_garbage_enabled" or
           key == "ipv6_script_enabled" or key == "hotplug_enabled" then
            admin_config[key] = (value == "1")
        -- 处理数值转换
                elseif key == "refresh_interval" or key == "history_size" or 
                       key == "blacklist_duration" or key == "logs_refresh_interval" or 
                       key == "logs_display_lines" or key == "ipv6_script_interval" then
            admin_config[key] = tonumber(value)
        else
            admin_config[key] = value
        end
    end
end
    end
    
    return admin_config
end

-- 获取OpenVPN实例名称
function get_openvpn_instance()
    local config = get_admin_config()
    return config.openvpn_instance
end

-- 获取OpenVPN配置文件路径
function get_openvpn_config_path()
    local config = get_admin_config()
    return config.openvpn_config_path
end

-- 获取刷新间隔
function get_refresh_interval()
    local config = get_admin_config()
    if config.refresh_enabled then
        return config.refresh_interval
    end
    return 0  -- 禁用自动刷新
end

-- 获取历史记录行数
function get_history_size()
    local config = get_admin_config()
    return config.history_size or 20
end

-- 获取黑名单配置
function get_blacklist_config()
    local config = get_admin_config()
    return {
        duration = config.blacklist_duration,
        file = config.blacklist_file
    }
end

-- 获取日志文件路径
function get_log_file()
    local config = get_admin_config()
    return config.log_file
end

-- 获取历史文件路径
function get_history_file()
    local config = get_admin_config()
    return config.history_file
end

-- 获取证书相关路径
function get_cert_paths()
    local config = get_admin_config()
    return {
        easyrsa_dir = config.easyrsa_dir,
        easyrsa_pki = config.easyrsa_pki,
        openvpn_pki = config.openvpn_pki
    }
end

-- 获取脚本路径
function get_script_paths()
    local config = get_admin_config()
    return {
        generate_client_script = config.generate_client_script,
        renew_cert_script = config.renew_cert_script,
        clean_garbage_script = config.clean_garbage_script
    }
end

-- 获取日志页面配置
function get_logs_config()
    local config = get_admin_config()
    return {
        refresh_enabled = config.logs_refresh_enabled,
        refresh_interval = config.logs_refresh_interval or 10,
        display_lines = config.logs_display_lines or 1000
    }
end

-- 获取临时文件目录
function get_temp_dir()
    local config = get_admin_config()
    return config.temp_dir or "/tmp/openvpn-admin"
end

-- 更新cron任务
-- 清理cron文件中的特定关键词行
function clean_cron_lines(content, keywords)
    local new_lines = {}
    for line in content:gmatch("[^\r\n]+") do
        local skip = false
        
        -- 检查是否包含任何关键词
        for _, keyword in ipairs(keywords) do
            if line:match(keyword) then
                skip = true
                break
            end
        end
        
        if not skip then
            table.insert(new_lines, line)
        end
    end
    
    return new_lines
end

function update_cron_job()
    local config = get_admin_config()
    local cron_file = "/etc/crontabs/root"
    
    -- 读取现有的cron文件
    local cron_content = ""
    if sys.call("test -f " .. cron_file .. " 2>/dev/null") == 0 then
        cron_content = sys.exec("cat " .. cron_file .. " 2>/dev/null")
    end
    
    -- 移除所有OpenVPN相关的行（包括注释）
    local keywords = {"[Oo]pen[Vv][Pp][Nn]", "clean%-garbage", "垃圾清理"}
    local new_lines = clean_cron_lines(cron_content, keywords)
    
    -- 只有在启用时才添加任务行（不加注释）
    if config.clean_garbage_enabled then
        local hour, minute = config.clean_garbage_time:match("(%d+):(%d+)")
        if not hour or not minute then
            hour, minute = "4", "50"
        end
        
        local script_path = config.clean_garbage_script or "/etc/openvpn/clean-garbage.sh"
        
        if sys.call("test -f " .. script_path .. " 2>/dev/null") ~= 0 then
            create_clean_garbage_script(script_path, config.temp_dir)
        end
        
        -- 只添加任务行，不加注释
        table.insert(new_lines, string.format("%s %s * * * %s", minute, hour, script_path))
    end
    
    -- 写入文件
    local temp_cron = "/tmp/root.cron.tmp"
    local fd = io.open(temp_cron, "w")
    if fd then
        fd:write(table.concat(new_lines, "\n"))
        fd:close()
        sys.exec("mv " .. temp_cron .. " " .. cron_file .. " 2>/dev/null")
        sys.exec("chmod 644 " .. cron_file .. " 2>/dev/null")
        sys.exec("/etc/init.d/cron restart 2>/dev/null")
        return true
    end
    return false
end

function update_ipv6_cron_job()
    local config = get_admin_config()
    local cron_file = "/etc/crontabs/root"
    
    -- 读取现有的cron文件
    local cron_content = ""
    if sys.call("test -f " .. cron_file .. " 2>/dev/null") == 0 then
        cron_content = sys.exec("cat " .. cron_file .. " 2>/dev/null")
    end
    
    -- 移除所有IPv6相关的行（包括注释）
    local keywords = {"[Ii][Pp]v6", "openvpn_ipv6"}
    local new_lines = clean_cron_lines(cron_content, keywords)
    
    -- 如果启用IPv6脚本，只添加任务行（不加注释）
    if config.ipv6_script_enabled and config.ipv6_script_path then
        local script_exists = sys.call("test -f " .. config.ipv6_script_path .. " 2>/dev/null") == 0
        
        if script_exists then
            -- 只添加定时任务行，不加注释
            table.insert(new_lines, string.format("*/%d * * * * %s 2>&1", 
                config.ipv6_script_interval, config.ipv6_script_path))
            
            sys.exec("chmod +x " .. config.ipv6_script_path .. " 2>/dev/null")
        end
    end
    
    -- 写入文件
    local temp_cron = "/tmp/root.cron.tmp"
    local fd = io.open(temp_cron, "w")
    if fd then
        fd:write(table.concat(new_lines, "\n"))
        fd:close()
        sys.exec("mv " .. temp_cron .. " " .. cron_file .. " 2>/dev/null")
        sys.exec("chmod 644 " .. cron_file .. " 2>/dev/null")
        sys.exec("/etc/init.d/cron restart 2>/dev/null")
        return true
    end
    return false
end



-- 运行IPv6脚本（如果启用）
function run_ipv6_script_if_enabled()
    local config = get_admin_config()
    
    if config.ipv6_script_enabled and config.ipv6_script_path then
        local script_exists = sys.call("test -f " .. config.ipv6_script_path .. " 2>/dev/null") == 0
        
        if script_exists then
            -- 确保脚本有执行权限
            sys.exec("chmod +x " .. config.ipv6_script_path .. " 2>/dev/null")
            
            -- 运行脚本并记录日志
            local output = sys.exec(config.ipv6_script_path .. " 2>&1")
            nixio.syslog("info", "OpenVPN IPv6脚本执行结果: " .. output)
            
            return true
        else
            nixio.syslog("warning", "IPv6脚本不存在: " .. config.ipv6_script_path)
            return false
        end
    end
    
    return nil  -- 表示脚本未启用
end

-- 创建垃圾清理脚本
function create_clean_garbage_script(script_path, temp_dir)
    local dir = script_path:match("^(.*/)[^/]*$")
    if dir then
        sys.exec("mkdir -p " .. dir .. " 2>/dev/null")
    end
    
    local script_content = [[
#!/bin/sh
# OpenVPN管理插件垃圾清理脚本

# 临时文件目录
TEMP_DIR="]] .. (temp_dir or "/tmp/openvpn-admin") .. [["

# 日志文件
LOG_FILE="/var/log/openvpn-admin-clean.log"

# 检查临时目录是否存在
if [ ! -d "$TEMP_DIR" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] 临时目录不存在: $TEMP_DIR" >> "$LOG_FILE"
    exit 1
fi

# 清理临时文件（保留最近1天的文件）
echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] 开始清理临时目录: $TEMP_DIR" >> "$LOG_FILE"

# 删除超过1天的临时文件
find "$TEMP_DIR" -type f -mtime +1 -delete 2>/dev/null

# 删除空目录
find "$TEMP_DIR" -type d -empty -delete 2>/dev/null

# 统计清理结果
REMAINING_FILES=$(find "$TEMP_DIR" -type f | wc -l)
REMAINING_DIRS=$(find "$TEMP_DIR" -type d | wc -l)

echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] 清理完成，剩余文件: $REMAINING_FILES，剩余目录: $REMAINING_DIRS" >> "$LOG_FILE"

# 限制日志文件大小
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$LOG_SIZE" -gt 1048576 ]; then  # 大于1MB
        tail -1000 "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
fi

exit 0
]]
    
    local fd = io.open(script_path, "w")
    if fd then
        fd:write(script_content)
        fd:close()
        sys.exec("chmod +x " .. script_path .. " 2>/dev/null")
        return true
    end
    return false
end

-- 创建hotplug脚本
function create_hotplug_script(config)
    local script_path = config.hotplug_script_path or "/etc/openvpn/openvpn_hotplug.sh"
    local dir = script_path:match("^(.*/)[^/]*$")
    
    if dir then
        sys.exec("mkdir -p " .. dir .. " 2>/dev/null")
    end
    
    local script_content = [[
#!/bin/sh

# OpenVPN Hotplug IPv6地址更新脚本
# 自动检测网络接口变化并更新OpenVPN的IPv6地址

# 配置文件
CONFIG_FILE="/etc/config/openvpn"
OPENVPN_SECTION="]] .. (config.openvpn_instance or "myvpn") .. [["
MONITOR_INTERFACE="]] .. (config.hotplug_interface or "") .. [["
LOG_DIR="]] .. (config.temp_dir or "/tmp/openvpn-admin") .. [["
LOG_FILE="$LOG_DIR/hotplug_ipv6.log"
MAX_LOG_LINES=50

# 确保日志目录存在
mkdir -p "$LOG_DIR" 2>/dev/null

# 优化的日志函数
log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S') - $1"
    local temp_file="${LOG_FILE}.tmp"
    
    # 如果日志文件存在且行数超过限制，保留最新的(MAX_LOG_LINES-1)行
    if [ -f "$LOG_FILE" ]; then
        tail -n $((MAX_LOG_LINES - 1)) "$LOG_FILE" > "$temp_file" 2>/dev/null
    fi
    
    # 添加新日志
    echo "$message" >> "$temp_file"
    
    # 替换原日志文件
    mv "$temp_file" "$LOG_FILE" 2>/dev/null || true
}

# 获取指定接口的公网IPv6地址
get_public_ipv6() {
    local interface="$1"
    
    if [ -z "$interface" ]; then
        echo ""
        return 1
    fi
    
    # 获取全局IPv6地址（非本地链路地址，以2开头的公网地址）
    ip -6 addr show dev "$interface" 2>/dev/null | \
        grep -E 'inet6.*global' | \
        grep -v 'deprecated' | \
        awk '{print $2}' | \
        cut -d'/' -f1 | \
        grep -E '^2[0-9a-f][0-9a-f][0-9a-f]' | \
        head -1
}

# 获取配置的IPv6地址
get_configured_ipv6() {
    uci -q get openvpn.$OPENVPN_SECTION.local 2>/dev/null
}

# 检查OpenVPN是否启用了IPv6
openvpn_has_ipv6() {
    uci -q get openvpn.$OPENVPN_SECTION.local >/dev/null 2>&1
    return $?
}

# 主处理函数
process_interface_change() {
    local action="$1"
    local interface="$2"
    
    log_message "接口事件: $action $interface"
    
    # 只处理我们监控的接口
    if [ "$interface" != "$MONITOR_INTERFACE" ]; then
        log_message "忽略非监控接口: $interface"
        return 0
    fi
    
    if [ "$action" = "ifup" ] || [ "$action" = "ifupdate" ]; then
        log_message "检测到接口 $interface 状态变化"
        
        # 等待网络稳定
        sleep 2
        
        # 获取当前IPv6地址
        current_ipv6=$(get_public_ipv6 "$interface")
        
        if [ -z "$current_ipv6" ]; then
            log_message "警告: 接口 $interface 上没有可用的公网IPv6地址"
            return 1
        fi
        
        log_message "当前IPv6地址: $current_ipv6"
        
        # 检查OpenVPN是否启用了IPv6
        if openvpn_has_ipv6; then
            configured_ipv6=$(get_configured_ipv6)
            
            if [ -z "$configured_ipv6" ]; then
                log_message "OpenVPN配置中无IPv6地址，设置为: $current_ipv6"
                uci set openvpn.$OPENVPN_SECTION.local="$current_ipv6"
                uci commit openvpn
                /etc/init.d/openvpn restart
                log_message "OpenVPN已重启"
            elif [ "$current_ipv6" != "$configured_ipv6" ]; then
                log_message "IPv6地址变更: $configured_ipv6 -> $current_ipv6"
                uci set openvpn.$OPENVPN_SECTION.local="$current_ipv6"
                uci commit openvpn
                /etc/init.d/openvpn restart
                log_message "OpenVPN已重启"
            else
                log_message "IPv6地址一致，无需更新"
            fi
        else
            log_message "OpenVPN未启用IPv6，跳过地址更新"
        fi
    fi
    
    return 0
}

# 主逻辑
case "$1" in
    ifup|ifdown|ifupdate)
        if [ -n "$2" ]; then
            process_interface_change "$1" "$2"
        fi
        ;;
    *)
        log_message "未知操作: $1"
        exit 1
        ;;
esac

exit 0
]]
    
    local fd = io.open(script_path, "w")
    if fd then
        fd:write(script_content)
        fd:close()
        sys.exec("chmod +x " .. script_path .. " 2>/dev/null")
        
        -- 创建hotplug配置目录和文件
        create_hotplug_config(config)
        
        return true
    end
    return false
end

-- 创建hotplug配置文件
function create_hotplug_config(config)
    local hotplug_dir = "/etc/hotplug.d/iface"
    local hotplug_script = config.hotplug_script_path or "/etc/openvpn/openvpn_hotplug.sh"
    
    -- 确保hotplug目录存在
    sys.exec("mkdir -p " .. hotplug_dir .. " 2>/dev/null")
    
    local config_content = [[
#!/bin/sh

# OpenVPN Hotplug配置
# 自动监控网络接口变化

[ "$ACTION" = "ifup" -o "$ACTION" = "ifdown" -o "$ACTION" = "ifupdate" ] || exit 0

# 只处理我们关心的接口
INTERFACE_TO_MONITOR="]] .. (config.hotplug_interface or "") .. [["

if [ "$INTERFACE" = "$INTERFACE_TO_MONITOR" ]; then
    # 执行OpenVPN hotplug脚本
    ]] .. hotplug_script .. [[ "$ACTION" "$INTERFACE" &
fi

exit 0
]]
    
    local config_file = hotplug_dir .. "/99-openvpn-admin"
    local fd = io.open(config_file, "w")
    if fd then
        fd:write(config_content)
        fd:close()
        sys.exec("chmod +x " .. config_file .. " 2>/dev/null")
        return true
    end
    return false
end

-- 检查防火墙规则是否存在
function check_firewall_rule()
    local rule_exists = false
    local rule_section = nil
    
    -- 遍历防火墙规则
    uci:foreach("firewall", "rule",
        function(section)
            if section.name == "openvpn" then
                rule_exists = true
                rule_section = section[".name"]
                return false  -- 停止遍历
            end
        end
    )
    
    return rule_exists, rule_section
end

-- 更新防火墙端口规则
function update_firewall_port(old_port, new_port)
    local result = false
    
    -- 查找现有的OpenVPN防火墙规则
    local rule_exists, rule_section = check_firewall_rule()
    
    if rule_exists and rule_section then
        -- 更新现有规则的端口
        local ok, err = pcall(function()
            uci:set("firewall", rule_section, "dest_port", new_port)
            uci:save("firewall")
            uci:commit("firewall")
        end)
        
        if ok then
            -- 重新加载防火墙
            local reload_result = sys.call("/etc/init.d/firewall reload >/dev/null 2>&1")
            if reload_result == 0 then
                nixio.syslog("info", string.format("OpenVPN防火墙规则已更新，端口从 %s 改为 %s", old_port, new_port))
                result = true
            else
                nixio.syslog("err", "防火墙重新加载失败")
            end
        else
            nixio.syslog("err", "更新防火墙规则失败: " .. tostring(err))
        end
    else
        -- 规则不存在，创建新规则
        result = add_firewall_port(new_port)
    end
    
    return result
end

-- 添加防火墙端口规则
function add_firewall_port(port)
    local result = false
    
    -- 创建新的防火墙规则
    local section_name = uci:add("firewall", "rule")
    
    if section_name then
        local ok, err = pcall(function()
            -- 设置规则参数
            uci:set("firewall", section_name, "name", "openvpn")
            uci:set("firewall", section_name, "src", "wan")
            uci:set("firewall", section_name, "proto", "tcp udp")  -- 同时允许TCP和UDP
            uci:set("firewall", section_name, "dest_port", port)
            uci:set("firewall", section_name, "target", "ACCEPT")
            
            -- 保存并提交
            uci:save("firewall")
            uci:commit("firewall")
        end)
        
        if ok then
            -- 重新加载防火墙
            local reload_result = sys.call("/etc/init.d/firewall reload >/dev/null 2>&1")
            if reload_result == 0 then
                nixio.syslog("info", string.format("已添加OpenVPN防火墙规则，端口: %s", port))
                result = true
            else
                nixio.syslog("err", "防火墙重新加载失败")
                -- 回滚：删除刚创建的规则
                uci:delete("firewall", section_name)
                uci:save("firewall")
                uci:commit("firewall")
            end
        else
            nixio.syslog("err", "添加防火墙规则失败: " .. tostring(err))
            -- 回滚
            uci:delete("firewall", section_name)
            uci:save("firewall")
        end
    else
        nixio.syslog("err", "无法创建防火墙规则section")
    end
    
    return result
end

-- 检查防火墙端口规则（AJAX接口）
function check_firewall_rule_ajax()
    local result = {
        success = false,
        exists = false,
        message = ""
    }
    
    local port = http.formvalue("port")
    local instance = get_openvpn_instance()
    
    if not port then
        -- 如果没有提供端口，从OpenVPN配置中获取
        port = uci:get("openvpn", instance, "port")
    end
    
    if port then
        -- 检查防火墙规则是否存在
        local rule_exists, rule_section = check_firewall_rule()
        
        if rule_exists then
            -- 检查端口是否匹配
            local current_port = uci:get("firewall", rule_section, "dest_port")
            result.exists = (current_port == port)
            result.current_port = current_port
            result.expected_port = port
            result.success = true
            result.message = "防火墙规则检查完成"
        else
            result.exists = false
            result.success = true
            result.message = "防火墙规则不存在"
        end
    else
        result.message = "未指定端口"
    end
    
    http.write_json(result)
end

function index()

    
    -- 主菜单项：作为目录入口，使用alias重定向到状态页面
    entry({"admin", "vpn", "openvpn-admin"}, 
          alias("admin", "vpn", "openvpn-admin", "status"), 
          _("OpenVPN Admin"), 
          60).index = true
    
    -- 状态页面（默认页面）
    entry({"admin", "vpn", "openvpn-admin", "status"}, 
          call("action_status"), 
          _("服务状态"), 
          1)
    
    -- 客户端页面
    entry({"admin", "vpn", "openvpn-admin", "client"}, 
          template("openvpn-admin/client"), 
          _("客户端"), 
          2)
    
    -- 服务端页面
    entry({"admin", "vpn", "openvpn-admin", "server"}, 
          template("openvpn-admin/server"), 
          _("服务端"), 
          3)
    
    -- 日志页面（显示OpenVPN服务器日志）
    entry({"admin", "vpn", "openvpn-admin", "logs"}, 
          call("action_logs"), 
          _("日志"), 
          4)
    
    -- 设置页面（新增）
    entry({"admin", "vpn", "openvpn-admin", "settings"}, 
          call("action_settings"), 
          _("设置"), 
          5)
    
    -- AJAX接口：获取OpenVPN状态
    entry({"admin", "vpn", "openvpn-admin", "get_status"}, 
          call("get_openvpn_status"))
    
    -- AJAX接口：启动OpenVPN服务
    entry({"admin", "vpn", "openvpn-admin", "start_service"}, 
          call("start_openvpn_service"))
    
    -- AJAX接口：停止OpenVPN服务
    entry({"admin", "vpn", "openvpn-admin", "stop_service"}, 
          call("stop_openvpn_service"))
    
    -- AJAX接口：断开客户端连接
    entry({"admin", "vpn", "openvpn-admin", "disconnect_client"}, 
          call("disconnect_client"))
    
    -- AJAX接口：清除OpenVPN日志
    entry({"admin", "vpn", "openvpn-admin", "clear_logs"}, 
          call("clear_openvpn_logs"))
    
    -- AJAX接口：下载OpenVPN日志
    entry({"admin", "vpn", "openvpn-admin", "download_logs"}, 
          call("download_openvpn_logs"))
    
    -- AJAX接口：获取OpenVPN日志
    entry({"admin", "vpn", "openvpn-admin", "get_logs"}, 
          call("get_openvpn_logs"))
    
    -- AJAX接口：获取OpenVPN配置文件内容
    entry({"admin", "vpn", "openvpn-admin", "get_config"}, 
          call("get_openvpn_config"))
    
    -- AJAX接口：下载OpenVPN配置文件
    entry({"admin", "vpn", "openvpn-admin", "download_config"}, 
          call("download_openvpn_config"))
    
    -- AJAX接口：获取配置节详情
    entry({"admin", "vpn", "openvpn-admin", "get_section"}, 
          call("get_config_section"))
    
    -- AJAX接口：保存OpenVPN配置
    entry({"admin", "vpn", "openvpn-admin", "save_config"}, 
          call("save_openvpn_config"))
    
    -- AJAX接口：应用OpenVPN配置（保存并重启服务）
    entry({"admin", "vpn", "openvpn-admin", "apply_config"}, 
          call("apply_openvpn_config"))
    
    -- AJAX接口：获取客户端黑名单（基于CN）
    entry({"admin", "vpn", "openvpn-admin", "get_blacklist_cn"}, 
          call("get_blacklist_cn"))
    
    -- AJAX接口：从黑名单中移除客户端（基于CN）
    entry({"admin", "vpn", "openvpn-admin", "remove_from_blacklist_cn"}, 
          call("remove_from_blacklist_cn"))
    
    -- AJAX接口：添加客户端到黑名单（基于CN）
    entry({"admin", "vpn", "openvpn-admin", "add_to_blacklist"}, 
          call("add_client_to_blacklist"))
    
    -- AJAX接口：查找客户端ID
    entry({"admin", "vpn", "openvpn-admin", "find_client_id"}, 
          call("find_client_id"))
    
    -- AJAX接口：生成客户端配置
    entry({"admin", "vpn", "openvpn-admin", "generate_client_config"}, 
          call("generate_client_config"))
    
    -- AJAX接口：重置所有证书
    entry({"admin", "vpn", "openvpn-admin", "reset_all_certificates"}, 
          call("reset_all_certificates"))
    
    -- AJAX接口：下载客户端配置文件
    entry({"admin", "vpn", "openvpn-admin", "download_client_config"}, 
          call("download_client_config"))
    
    -- AJAX接口：获取管理配置（新增）
    entry({"admin", "vpn", "openvpn-admin", "get_admin_config"}, 
          call("get_admin_config_ajax"))
    
    -- AJAX接口：保存管理配置（新增）
    entry({"admin", "vpn", "openvpn-admin", "save_admin_config"}, 
          call("save_admin_config"))
    
    -- AJAX接口：获取OpenVPN UCI配置（新增）
    entry({"admin", "vpn", "openvpn-admin", "get_uci_config"}, 
          call("get_openvpn_uci_config"))
    
    -- AJAX接口：保存OpenVPN UCI配置（新增）
    entry({"admin", "vpn", "openvpn-admin", "save_uci_config"}, 
          call("save_openvpn_uci_config"))
    
    -- AJAX接口：检查防火墙规则（新增）
    entry({"admin", "vpn", "openvpn-admin", "check_firewall"}, 
          call("check_firewall_rule_ajax"))
          
    -- 新增AJAX接口：获取网络接口列表
    entry({"admin", "vpn", "openvpn-admin", "get_interfaces"}, 
          call("action_get_interfaces"))
    
    -- 新增AJAX接口：获取接口IPv6地址
    entry({"admin", "vpn", "openvpn-admin", "get_interface_ipv6"}, 
          call("action_get_interface_ipv6"))      
          
    -- AJAX接口：检查IPv6脚本是否存在
    entry({"admin", "vpn", "openvpn-admin", "check_ipv6_script"}, 
          call("action_check_ipv6_script"),  -- 修改函数名为action_check_ipv6_script
          nil).leaf = true   
end

-- 获取网络接口列表
function action_get_interfaces()
    local result = {
        success = false,
        interfaces = {},
        message = ""
    }
    
    -- 直接获取所有活跃的网络接口
    local cmd = "ip -o link show 2>/dev/null | grep -v 'LOOPBACK' | grep -v 'link-netns' | awk '{print $2}' | sed 's/:$//'"
    local output = sys.exec(cmd)
    
    if output and output ~= "" then
        for ifname in output:gmatch("[^\r\n]+") do
            ifname = util.trim(ifname)
            
            -- 跳过虚拟接口和docker接口
            if not ifname:match("^lo$") and 
               not ifname:match("^docker") and 
               not ifname:match("^veth") and
               not ifname:match("^ip6tnl") and
               not ifname:match("^tunl") and
               not ifname:match("^sit") and
               not ifname:match("^dummy") and
               not ifname:match("^gre") and
               not ifname:match("^gretap") and
               not ifname:match("^erspan") and
               not ifname:match("^siit") and
               not ifname:match("^teql") then
                
                -- 检查接口状态
                local status_cmd = "cat /sys/class/net/" .. ifname .. "/operstate 2>/dev/null || echo 'down'"
                local status = sys.exec(status_cmd)
                status = util.trim(status or "down")
                
                -- 获取接口类型
                local type_cmd = "cat /sys/class/net/" .. ifname .. "/type 2>/dev/null || echo '0'"
                local iftype = tonumber(sys.exec(type_cmd)) or 0
                
                -- 1=ethernet, 32=bridge, 772=loopback, 65534=tun/tap
                if iftype == 1 or iftype == 32 or iftype == 65534 then
                    table.insert(result.interfaces, {
                        name = ifname,
                        status = (status == "up") and "up" or "down",
                        display = ifname .. " (" .. status:upper() .. ")",
                        config_name = ifname
                    })
                end
            end
        end
    end
    
    -- 按名称排序
    table.sort(result.interfaces, function(a, b)
        return a.name < b.name
    end)
    
    result.success = true
    
    http.write_json(result)
end

-- 获取指定接口的IPv6地址
function action_get_interface_ipv6()
    local result = {
        success = false,
        ipv6_address = "",
        message = ""
    }
    
    local interface = http.formvalue("interface")
    
    if not interface or interface == "" then
        result.message = "未指定网络接口"
        http.write_json(result)
        return
    end
    
    -- 获取接口的所有IPv6地址
    local cmd = "ip -6 addr show dev " .. interface .. " 2>/dev/null | grep 'inet6.*global'"
    local ipv6_output = sys.exec(cmd)
    
    if ipv6_output and ipv6_output ~= "" then
        -- 优先选择公网IPv6地址
        for line in ipv6_output:gmatch("[^\r\n]+") do
            local ipv6_address = line:match("inet6%s+([%x:]+)/")
            if ipv6_address then
                -- 检查是否是公网地址 (240e:: 开头)
                if ipv6_address:match("^240e:") then
                    result.ipv6_address = ipv6_address
                    result.success = true
                    break
                end
                -- 如果没有公网地址，使用第一个找到的全局地址
                if result.ipv6_address == "" then
                    result.ipv6_address = ipv6_address
                    result.success = true
                end
            end
        end
        
        if result.ipv6_address == "" then
            result.message = "接口 " .. interface .. " 没有全局IPv6地址"
        end
    else
        result.message = "接口 " .. interface .. " 没有全局IPv6地址"
    end
    
    http.write_json(result)
end

-- 检查IPv6脚本函数
function action_check_ipv6_script()
    -- 这个版本完全手动处理，不依赖任何可能缺失的库
    local req = require "luci.http"
    
    -- 立即设置响应类型
    req.header("Content-Type", "text/plain")  -- 先设为文本
    
    local result = {}
    
    -- 获取参数
    local query_string = os.getenv("QUERY_STRING") or ""
    local path = ""
    
    -- 手动解析查询字符串
    for param in query_string:gmatch("[^&]+") do
        local key, value = param:match("([^=]+)=?(.*)")
        if key == "path" then
            path = req.urldecode(value or "")
            break
        end
    end
    
    -- 如果路径为空，使用默认值
    if path == "" then
        local config = get_admin_config()
        path = config.ipv6_script_path or "/etc/openvpn/openvpn_ipv6"
    end
    
    -- 检查文件
    local exists = os.execute("test -f " .. path .. " 2>/dev/null") == 0
    local executable = os.execute("test -x " .. path .. " 2>/dev/null") == 0
    local valid = false
    
    if exists then
        local f = io.open(path, "r")
        if f then
            local first_line = f:read("*l") or ""
            f:close()
            if first_line:find("^#!/bin/sh") or first_line:find("^#!/bin/bash") then
                valid = true
                result.message = "有效的shell脚本"
            else
                result.message = "不是有效的shell脚本"
            end
        else
            result.message = "无法读取文件"
        end
    else
        result.message = "文件不存在: " .. path
    end
    
    -- 构建结果
    result.success = exists
    result.exists = exists
    result.executable = executable
    result.valid = valid
    result.path = path
    
    -- 输出JSON（手动格式）
    local json = string.format(
        '{\n' ..
        '  "success": %s,\n' ..
        '  "exists": %s,\n' ..
        '  "executable": %s,\n' ..
        '  "valid": %s,\n' ..
        '  "message": "%s",\n' ..
        '  "path": "%s"\n' ..
        '}',
        tostring(result.success):lower(),
        tostring(result.exists):lower(),
        tostring(result.executable):lower(),
        tostring(result.valid):lower(),
        (result.message or ""):gsub('"', '\\"'),
        (result.path or ""):gsub('"', '\\"')
    )
    
    req.header("Content-Type", "application/json")
    req.write(json)
    
    return
end

-- 设置页面
function action_settings()
    local template = require("luci.template")
    local config = get_admin_config()
    
    template.render("openvpn-admin/settings", {
        config = config
    })
end

-- 获取管理配置（AJAX接口）
function get_admin_config_ajax()
    local result = {
        success = true,
        data = get_admin_config(),
        message = ""
    }
    
    http.write_json(result)
end

-- 保存管理配置（AJAX接口）
function save_admin_config()
    local result = {
        success = false,
        message = ""
    }
    
    -- 获取所有配置参数（包含新增的）
    local params = {
        "openvpn_instance",
        "openvpn_config_path",
        "refresh_enabled",
        "refresh_interval",
        "history_size",
        "blacklist_duration",
        "blacklist_file",
        "log_file",
        "history_file",
        "blacklist_file",
        "easyrsa_dir",
        "easyrsa_pki",
        "openvpn_pki",
        "logs_refresh_enabled",
        "logs_refresh_interval",
        "logs_display_lines",
        "generate_client_script",
        "renew_cert_script",
        -- 新增配置项
        "temp_dir",
        "clean_garbage_enabled",
        "clean_garbage_time",
        "clean_garbage_script",
        -- 新增：IPv6脚本配置
        "ipv6_script_path",
        "ipv6_script_interval",
        "ipv6_script_enabled",
        -- 新增hotplug配置
        "hotplug_enabled",
        "hotplug_interface",
        "hotplug_ipv6_address",
        "hotplug_script_path"
    }
    
    local section = uci:get_first("openvpn-admin", "settings")
    
    if not section then
        -- 创建新的section
        uci:section("openvpn-admin", "settings", "global", {})
        section = "global"
    end
    
    -- 更新配置
    for _, param in ipairs(params) do
        local value = http.formvalue(param)
        if value then
            uci:set("openvpn-admin", section, param, value)
        end
    end
    
    -- 提交更改
    if uci:save("openvpn-admin") then
        uci:commit("openvpn-admin")
        
        -- 清除缓存
        admin_config = nil
        
        -- 更新cron任务
        update_cron_job()
        
        -- 更新IPv6定时任务
        update_ipv6_cron_job()
        
        -- -- 获取更新后的配置
        local config = get_admin_config()
        
        -- 如果启用了hotplug，创建或更新脚本
        if config.hotplug_enabled and config.hotplug_interface ~= "" then
            create_hotplug_script(config)
            -- 设置hotplug脚本的执行权限
            if config.hotplug_script_path then
                sys.exec("chmod +x " .. config.hotplug_script_path .. " 2>/dev/null")
            end
        end
        
        -- 确保临时目录存在
        sys.exec("mkdir -p " .. config.temp_dir .. " 2>/dev/null")
        
        result.success = true
        result.message = "配置保存成功"
    else
        result.message = "配置保存失败"
    end
    
    http.write_json(result)
end

-- 连接状态页面
function action_status()
    local config = get_admin_config()
    
    -- 获取OpenVPN版本
    local version = get_openvpn_version()
    
    -- 检查OpenVPN服务状态
    local service_status, service_color, service_text = check_openvpn_service()
    
    -- 通过management接口获取当前连接数据
    local connected_clients, last_activity = get_current_connections_via_management()
    local total_connected = #(connected_clients or {})
    
    -- 获取最近连接记录
    local history_size = config.history_size or 20
    local connection_history = get_recent_connection_history(history_size)
    
    -- 为每个客户端添加Client ID
    for _, client in ipairs(connected_clients or {}) do
        if not client.client_id or client.client_id == "N/A" then
            client.client_id = extract_client_id_from_management(client.name)
        end
    end
    
    -- 准备模板数据
    local template = require("luci.template")
    template.render("openvpn-admin/status", {
        last_activity = last_activity or "N/A",
        version = version,
        service_status = service_status,
        service_color = service_color,
        service_text = service_text,
        total_connected = total_connected,
        connected_clients = connected_clients or {},
        connection_history = connection_history or {},
        format_bytes = format_bytes,
        calculate_total_data = calculate_total_data,
        config = config
    })
end

-- 从management接口提取Client ID
function extract_client_id_from_management(client_name)
    if not client_name or client_name == "" then
        return "N/A"
    end
    
    -- 从OpenVPN配置获取management接口配置
    local management_ip, management_port = get_openvpn_management_config()
    
    if not management_ip or not management_port then
        return "N/A"
    end
    
    -- 尝试通过management接口获取状态
    local management_output = sys.exec(string.format("echo 'status 2' | nc %s %s 2>/dev/null | tail -n +3", management_ip, management_port))
    
    if management_output and management_output ~= "" then
        for line in management_output:gmatch("[^\r\n]+") do
            line = util.trim(line)
            
            if line:match("^CLIENT_LIST,") then
                local parts = util.split(line, ",")
                
                if #parts >= 13 then
                    local name = parts[2] or ""
                    if name == client_name then
                        local client_id = parts[11] or "N/A"
                        return client_id
                    end
                end
            end
        end
    end
    
    return "N/A"
end

-- 日志页面
function action_logs()
    local config = get_admin_config()
    
    -- 获取日志页面配置
    local logs_config = get_logs_config()
    
    -- 读取日志内容
    local log_content = ""
    local logs_display_lines = logs_config.display_lines or 1000
    local log_file = config.log_file or "/tmp/openvpn.log"
    
    if sys.call("test -f " .. log_file .. " 2>/dev/null") == 0 then
        -- 直接使用tail读取，不使用tac命令
        local content = sys.exec("tail -" .. logs_display_lines .. " " .. log_file .. " 2>/dev/null")
        if content and content ~= "" then
            -- 使用Lua代码反转行顺序，让最新日志在最上面
            local lines = util.split(content, "\n")
            local reversed_lines = {}
            for i = #lines, 1, -1 do
                table.insert(reversed_lines, lines[i])
            end
            log_content = table.concat(reversed_lines, "\n")
        end
    else
        log_content = "日志文件不存在: " .. log_file
    end
    
    -- 准备模板数据
    local template = require("luci.template")
    template.render("openvpn-admin/logs", {
        config = config,
        logs_config = logs_config,
        log_content = log_content,
        logs_display_lines = logs_display_lines
    })
end

-- 获取OpenVPN日志（AJAX接口）- 修复版，不使用tac命令
function get_openvpn_logs()
    local result = {
        success = false,
        data = {},
        message = ""
    }
    
    local log_file = get_log_file()
    local config = get_admin_config()
    local logs_display_lines = config.logs_display_lines or 1000
    
    if sys.call("test -f " .. log_file .. " 2>/dev/null") == 0 then
        -- 使用安全的读取方式，避免使用tac命令
        local content = ""
        
        -- 使用tail命令读取
        content = sys.exec("tail -" .. logs_display_lines .. " " .. log_file .. " 2>/dev/null")
        
        if content and content ~= "" then
            -- 使用Lua代码反转行顺序，让最新日志在最上面
            local lines = util.split(content, "\n")
            local reversed_lines = {}
            for i = #lines, 1, -1 do
                table.insert(reversed_lines, lines[i])
            end
            content = table.concat(reversed_lines, "\n")
            
            result.data.log_content = content
            result.success = true
        else
            result.message = "无法读取日志文件"
        end
    else
        result.message = "日志文件不存在"
    end
    
    http.write_json(result)
end

-- 清除OpenVPN日志
function clear_openvpn_logs()
    local result = {
        success = false,
        message = ""
    }
    
    local log_file = get_log_file()
    
    -- 清空日志文件
    local ret = sys.call("echo '' > " .. log_file .. " 2>/dev/null")
    
    if ret == 0 then
        result.success = true
        result.message = "日志已清空"
    else
        result.message = "日志清空失败"
    end
    
    http.write_json(result)
end

-- 下载OpenVPN日志
function download_openvpn_logs()
    local filename = get_log_file()
    
    if sys.call("test -f " .. filename .. " 2>/dev/null") == 0 then
        local content = sys.exec("cat " .. filename .. " 2>/dev/null")
        
        -- 设置HTTP头以下载文件
        http.header('Content-Type', 'text/plain')
        http.header('Content-Disposition', 'attachment; filename="openvpn.log"')
        http.header('Content-Length', tostring(#content))
        
        http.write(content)
    else
        http.status(404, "File not found")
        http.write("日志文件不存在")
    end
end

-- 获取OpenVPN状态信息（AJAX接口）
function get_openvpn_status()
    local result = {
        success = false,
        data = {},
        message = ""
    }
    
    -- 获取OpenVPN版本
    local version = get_openvpn_version()
    
    -- 检查OpenVPN服务状态
    local service_status, service_color, service_text = check_openvpn_service()
    
    -- 通过management接口获取当前连接数据
    local connected_clients, last_activity = get_current_connections_via_management()
    
    -- 为每个客户端添加Client ID
    for _, client in ipairs(connected_clients or {}) do
        if not client.client_id or client.client_id == "N/A" then
            client.client_id = extract_client_id_from_management(client.name)
        end
    end
    
    -- 获取最近连接记录
    local config = get_admin_config()
    local history_size = config.history_size or 20
    local connection_history = get_recent_connection_history(history_size)
    
    -- 获取客户端黑名单
    local blacklist_config = get_blacklist_config()
    local blacklist_cn = {}
    
    if blacklist_config.enabled then
        blacklist_cn = get_client_blacklist_cn()
    end
    
    result.data = {
        version = version,
        service_status = service_status,
        service_color = service_color,
        service_text = service_text,
        last_activity = last_activity or "N/A",
        connected_clients = connected_clients or {},
        total_connected = #(connected_clients or {}),
        connection_history = connection_history or {},
        blacklist_cn = blacklist_cn or {},
        refresh_interval = get_refresh_interval()
    }
    
    result.success = true
    http.write_json(result)
end

-- 获取OpenVPN版本信息
function get_openvpn_version()
    local version = "N/A"
    local version_output = sys.exec("openvpn --version 2>/dev/null | head -1")
    
    if version_output and version_output ~= "" then
        local match = version_output:match("OpenVPN ([%d%.]+)")
        if match then
            version = "OpenVPN " .. match
        else
            version = util.trim(version_output)
            if #version > 50 then
                version = version:sub(1, 47) .. "..."
            end
        end
    end
    
    if type(version) == "table" then
        version = tostring(version)
    elseif type(version) ~= "string" then
        version = "N/A"
    end
    
    return version
end

-- 从OpenVPN配置文件中获取management接口配置（无日志版本）
function get_openvpn_management_config()
    local management_ip = "127.0.0.1"
    local management_port = "7505"
    
    local instance = get_openvpn_instance()
    
    if not instance or instance == "" then
        return management_ip, management_port
    end
    
    -- 方法1：使用UCI库直接获取
    local uci = require("luci.model.uci").cursor()
    
    -- 检查实例是否存在
    local exists = uci:get("openvpn", instance)
    if not exists then
        return management_ip, management_port
    end
    
    -- 尝试从UCI获取management配置
    local uci_management = uci:get("openvpn", instance, "management")
    
    if uci_management and uci_management ~= "" then
        -- 使用gmatch分割所有非空白字符
        local parts = {}
        for part in uci_management:gmatch("%S+") do
            table.insert(parts, part)
        end
        if #parts >= 2 then
            management_ip = parts[1]
            management_port = parts[2]
            return management_ip, management_port
        end
    end
    
    -- 方法2：从配置文件读取（备用）
    local config_path = get_openvpn_config_path()
    if config_path and sys.call("test -f " .. config_path .. " 2>/dev/null") == 0 then
        local config_content = sys.exec("cat " .. config_path .. " 2>/dev/null")
        if config_content then
            -- 查找指定实例的management配置
            local in_correct_instance = false
            for line in config_content:gmatch("[^\r\n]+") do
                local trimmed = util.trim(line)
                if trimmed:match("^config%s+openvpn%s+['\"]" .. instance .. "['\"]") then
                    in_correct_instance = true
                elseif trimmed:match("^config%s+") then
                    in_correct_instance = false
                end
                if in_correct_instance and trimmed:match("^option%s+management%s+") then
                    local value = trimmed:match("option%s+management%s+['\"]([^'\"]+)['\"]") or 
                                 trimmed:match("option%s+management%s+([^%s]+)")
                    if value then
                        local parts = {}
                        for part in value:gmatch("%S+") do
                            table.insert(parts, part)
                        end
                        if #parts >= 2 then
                            management_ip = parts[1]
                            management_port = parts[2]
                            return management_ip, management_port
                        end
                    end
                end
            end
        end
    end
    
    return management_ip, management_port
end

-- 从OpenVPN配置文件中获取端口和协议
function get_openvpn_port_and_proto()
    local port = 1194
    local proto = "udp"
    
    local instance = get_openvpn_instance()
    
    -- 尝试从uci配置中获取
    local uci_port = sys.exec(string.format("uci -q get openvpn.%s.port 2>/dev/null", instance))
    local uci_proto = sys.exec(string.format("uci -q get openvpn.%s.proto 2>/dev/null", instance))
    
    if uci_port and uci_port ~= "" then
        port = tonumber(util.trim(uci_port)) or port
    end
    
    if uci_proto and uci_proto ~= "" then
        proto = util.trim(uci_proto)
    end
    
    -- 如果uci获取失败，尝试从配置文件直接读取
    if port == 1194 and proto == "udp" then
        local config_path = get_openvpn_config_path()
        if sys.call("test -f " .. config_path .. " 2>/dev/null") == 0 then
            local config_content = sys.exec("cat " .. config_path .. " 2>/dev/null")
            if config_content then
                local in_correct_instance = false
                local instance_name = "'" .. instance .. "'"
                
                for line in config_content:gmatch("[^\r\n]+") do
                    local trimmed = util.trim(line)
                    
                    if trimmed:match("^config openvpn ") and trimmed:match(instance_name) then
                        in_correct_instance = true
                    elseif in_correct_instance and trimmed:match("^config ") then
                        in_correct_instance = false
                    end
                    
                    if in_correct_instance then
                        if trimmed:match("^option%s+port%s+") then
                            local match = trimmed:match("'([^']+)'") or trimmed:match('"([^"]+)"')
                            if match then
                                port = tonumber(match) or port
                            end
                        elseif trimmed:match("^option%s+proto%s+") then
                            local match = trimmed:match("'([^']+)'") or trimmed:match('"([^"]+)"')
                            if match then
                                proto = match:lower()
                            end
                        end
                    end
                end
            end
        end
    end
    
    return port, proto
end

-- 简化的OpenVPN状态检查（只检查进程）
function check_openvpn_service()
    local service_status = "stopped"
    local service_color = "red"
    local service_text = "已停止"
    
    -- 只检查进程是否存在（最可靠的指标）
    local process_found = false
    
    -- 方法1：使用pgrep检查
    local pgrep_result = sys.exec("pgrep -f 'openvpn' 2>/dev/null")
    if pgrep_result and pgrep_result ~= "" then
        pgrep_result = util.trim(pgrep_result)
        if pgrep_result:match("^%d+") then
            process_found = true
        end
    end
    
    -- 方法2：使用ps检查（备用）
    if not process_found then
        local ps_result = sys.exec("ps | grep -v grep | grep openvpn")
        if ps_result and ps_result ~= "" and ps_result:match("openvpn") then
            -- 检查是否有有效的PID
            local lines = util.split(ps_result, "\n")
            for _, line in ipairs(lines) do
                line = util.trim(line)
                if line:match("^%d+") and line:match("openvpn") then
                    process_found = true
                    break
                end
            end
        end
    end
    
    if process_found then
        service_status = "running"
        service_color = "green"
        service_text = "运行中"
    else
        service_status = "stopped"
        service_color = "red"
        service_text = "已停止"
    end
    
    return service_status, service_color, service_text
end

-- 通过management接口获取当前连接数据
function get_current_connections_via_management()
    local connected_clients = {}
    local last_activity = "N/A"
    
    -- 从OpenVPN配置获取management接口配置
    local management_ip, management_port = get_openvpn_management_config()
    
    if not management_ip or not management_port then
        return connected_clients, last_activity
    end
    
    -- 尝试通过management接口获取状态
    local management_output = sys.exec(string.format("echo 'status 2' | nc %s %s 2>/dev/null | tail -n +3", management_ip, management_port))
    
    if management_output and management_output ~= "" then
        last_activity = os.date("%Y-%m-%d %H:%M:%S")
        
        for line in management_output:gmatch("[^\r\n]+") do
            line = util.trim(line)
            
            if line:match("^CLIENT_LIST,") then
                local parts = util.split(line, ",")
                
                if #parts >= 13 then
                    local client_name = parts[2] or "N/A"
                    local real_address = parts[3] or "N/A"
                    local virtual_address = parts[4] or "N/A"
                    local bytes_received = tonumber(parts[6]) or 0
                    local bytes_sent = tonumber(parts[7]) or 0
                    local connect_time_str = parts[8] or ""
                    local connect_timestamp = tonumber(parts[9]) or os.time()
                    local client_id = parts[11] or "N/A"
                    local cipher = parts[13] or "N/A"
                    
                    -- 修复接收数据为0的问题
                    if bytes_received == 0 and bytes_sent > 0 then
                        bytes_received, bytes_sent = bytes_sent, bytes_received
                    end
                    
                    -- 计算连接时长
                    local current_time = os.time()
                    local duration_seconds = current_time - connect_timestamp
                    local duration_str = format_duration(duration_seconds)
                    
                    -- 格式化连接时间
                    local connect_time_formatted = ""
                    if connect_time_str ~= "" then
                        local timestamp_num = tonumber(connect_time_str)
                        if timestamp_num then
                            connect_time_formatted = os.date("%Y-%m-d %H:%M:%S", timestamp_num)
                        else
                            connect_time_formatted = connect_time_str
                        end
                    else
                        connect_time_formatted = os.date("%Y-%m-%d %H:%M:%S", connect_timestamp)
                    end
                    
                    local client = {
                        name = client_name,
                        real_address = real_address,
                        virtual_address = virtual_address,
                        bytes_received = bytes_received,
                        bytes_sent = bytes_sent,
                        connect_time = connect_time_str,
                        connect_time_formatted = connect_time_formatted,
                        connect_timestamp = connect_timestamp,
                        cipher = cipher,
                        duration = duration_str,
                        duration_seconds = duration_seconds,
                        total_data = bytes_received + bytes_sent,
                        client_id = client_id
                    }
                    table.insert(connected_clients, client)
                end
            end
        end
    else
        -- 如果management接口不可用，尝试从状态文件读取
        local status_file = "/tmp/openvpn-status.log"
        
        if sys.call("test -f " .. status_file .. " 2>/dev/null") == 0 then
            local status_content = sys.exec("cat " .. status_file .. " 2>/dev/null")
            
            if status_content and status_content ~= "" then
                last_activity = os.date("%Y-%m-%d %H:%M:%S")
                
                for line in status_content:gmatch("[^\r\n]+") do
                    line = util.trim(line)
                    
                    if line:match("^CLIENT_LIST,") then
                        local parts = util.split(line, ",")
                        
                        if #parts >= 13 then
                            local client_name = parts[2] or "N/A"
                            local real_address = parts[3] or "N/A"
                            local virtual_address = parts[4] or "N/A"
                            local bytes_received = tonumber(parts[6]) or 0
                            local bytes_sent = tonumber(parts[7]) or 0
                            local connect_time = parts[8] or "N/A"
                            local client_id = parts[11] or "N/A"
                            local cipher = parts[13] or "N/A"
                            
                            local connect_timestamp = os.time()
                            if connect_time ~= "N/A" then
                                local year, month, day, hour, min, sec = connect_time:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
                                if year then
                                    connect_timestamp = os.time{year=year, month=month, day=day, hour=hour, min=min, sec=sec}
                                else
                                    local ts = tonumber(connect_time)
                                    if ts then
                                        connect_timestamp = ts
                                        connect_time = os.date("%Y-%m-%d %H:%M:%S", ts)
                                    end
                                end
                            end
                            
                            local current_time = os.time()
                            local duration_seconds = current_time - connect_timestamp
                            local duration_str = format_duration(duration_seconds)
                            
                            local client = {
                                name = client_name,
                                real_address = real_address,
                                virtual_address = virtual_address,
                                bytes_received = bytes_received,
                                bytes_sent = bytes_sent,
                                connect_time = connect_time,
                                connect_time_formatted = connect_time,
                                connect_timestamp = connect_timestamp,
                                cipher = cipher,
                                duration = duration_str,
                                duration_seconds = duration_seconds,
                                total_data = bytes_received + bytes_sent,
                                client_id = client_id
                            }
                            table.insert(connected_clients, client)
                        end
                    end
                end
            end
        end
    end
    
    -- 更新连接记录
    update_connection_history(connected_clients)
    
    return connected_clients, last_activity
end

-- 格式化时长函数
function format_duration(seconds)
    if not seconds or seconds <= 0 then
        return "0秒"
    end
    
    local days = math.floor(seconds / 86400)
    local hours = math.floor((seconds % 86400) / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    
    local parts = {}
    
    if days > 0 then
        table.insert(parts, days .. "天")
    end
    if hours > 0 then
        table.insert(parts, hours .. "小时")
    end
    if minutes > 0 then
        table.insert(parts, minutes .. "分钟")
    end
    if secs > 0 or #parts == 0 then
        table.insert(parts, secs .. "秒")
    end
    
    return table.concat(parts)
end

-- 获取最近连接记录
function get_recent_connection_history(limit)
    local history_file = get_history_file()
    local history_data = {}
    
    -- 如果文件不存在，尝试创建目录和文件
    if sys.call("test -f " .. history_file .. " 2>/dev/null") ~= 0 then
        -- 创建目录
        local dir = history_file:match("^(.*/)[^/]*$")
        if dir then
            sys.exec("mkdir -p " .. dir .. " 2>/dev/null")
        end
        -- 创建空文件
        sys.exec("echo '[]' > " .. history_file .. " 2>/dev/null")
    end
    
    if sys.call("test -f " .. history_file .. " 2>/dev/null") == 0 then
        local history_content = sys.exec("cat " .. history_file .. " 2>/dev/null")
        if history_content and history_content ~= "" then
            local ok, data = pcall(json.parse, history_content)
            if ok and type(data) == "table" then
                history_data = data
                
                -- 为每条记录添加格式化时间
                for _, record in ipairs(history_data) do
                    if record.connect_timestamp then
                        record.connect_time_formatted = os.date("%Y-%m-%d %H:%M:%S", record.connect_timestamp)
                    end
                    if record.disconnect_timestamp and record.disconnect_timestamp > 0 then
                        record.disconnect_time_formatted = os.date("%Y-%m-%d %H:%M:%S", record.disconnect_timestamp)
                    end
                end
                
                -- 按连接时间倒序排序
                table.sort(history_data, function(a, b)
                    return (a.connect_timestamp or 0) > (b.connect_timestamp or 0)
                end)
            end
        end
    end
    
    -- 限制返回的记录数量
    if limit and #history_data > limit then
        local limited_history = {}
        for i = 1, math.min(limit, #history_data) do
            table.insert(limited_history, history_data[i])
        end
        return limited_history
    end
    
    return history_data
end

-- 更新连接记录
function update_connection_history(current_connections)
    local config = get_admin_config()
    local history_file = config.history_file
    local max_records = config.history_size or 20
    
    local history_data = get_recent_connection_history(nil)
    local current_time = os.time()
    local current_ids = {}
    
    -- 为当前连接生成ID
    for _, conn in ipairs(current_connections) do
        local connection_id = generate_connection_id(conn.name, conn.real_address, conn.connect_time)
        current_ids[connection_id] = true
        
        local found = false
        for _, record in ipairs(history_data) do
            if record.connection_id == connection_id then
                -- 更新现有记录
                record.bytes_received = conn.bytes_received
                record.bytes_sent = conn.bytes_sent
                record.total_data = conn.total_data
                record.is_connected = true
                record.disconnect_time = ""
                record.disconnect_time_formatted = ""
                record.disconnect_timestamp = 0
                record.cipher = conn.cipher or "N/A"
                record.duration = conn.duration
                record.duration_seconds = conn.duration_seconds
                record.client_id = conn.client_id or "N/A"
                found = true
                break
            end
        end
        
        if not found then
            -- 添加新记录
            table.insert(history_data, {
                name = conn.name,
                real_address = conn.real_address,
                virtual_address = conn.virtual_address,
                connect_time = conn.connect_time,
                connect_time_formatted = conn.connect_time_formatted,
                connect_timestamp = conn.connect_timestamp,
                disconnect_time = "",
                disconnect_time_formatted = "",
                disconnect_timestamp = 0,
                bytes_received = conn.bytes_received,
                bytes_sent = conn.bytes_sent,
                total_data = conn.total_data,
                is_connected = true,
                connection_id = connection_id,
                cipher = conn.cipher or "N/A",
                duration = conn.duration,
                duration_seconds = conn.duration_seconds,
                client_id = conn.client_id or "N/A"
            })
        end
    end
    
    -- 标记已断开的连接
    for _, record in ipairs(history_data) do
        if record.is_connected and not current_ids[record.connection_id] then
            if record.disconnect_time == "" then
                record.is_connected = false
                record.disconnect_time = os.date("%Y-%m-%d %H:%M:%S", current_time)
                record.disconnect_time_formatted = record.disconnect_time
                record.disconnect_timestamp = current_time
                if record.connect_timestamp and record.connect_timestamp > 0 then
                    record.duration_seconds = current_time - record.connect_timestamp
                    record.duration = format_duration(record.duration_seconds)
                end
            end
        end
    end
    
    -- 按连接时间倒序排序
    table.sort(history_data, function(a, b)
        return (a.connect_timestamp or 0) > (b.connect_timestamp or 0)
    end)
    
    -- 限制记录数量
    if #history_data > max_records then
        local new_history = {}
        for i = 1, max_records do
            table.insert(new_history, history_data[i])
        end
        history_data = new_history
    end
    
    -- 保存更新后的历史记录
    if #history_data > 0 then
        local json_data = json.stringify(history_data, true)
        local temp_file = "/tmp/openvpn_history.tmp"
        local temp_fd = io.open(temp_file, "w")
        if temp_fd then
            temp_fd:write(json_data)
            temp_fd:close()
            sys.exec("mv " .. temp_file .. " " .. history_file .. " 2>/dev/null")
        end
    end
end

-- 生成连接ID
function generate_connection_id(name, address, time_str)
    local str = (name or "") .. (address or "") .. (time_str or "")
    
    local md5_output = sys.exec("echo -n '" .. str:gsub("'", "'\\''") .. "' | md5sum 2>/dev/null | cut -d' ' -f1")
    
    if md5_output and md5_output ~= "" then
        return util.trim(md5_output)
    else
        local hash = 0
        for i = 1, #str do
            hash = (hash * 31 + string.byte(str, i)) % 0x7FFFFFFF
        end
        return tostring(hash)
    end
end

-- 启动OpenVPN服务
function start_openvpn_service()
    local result = {
        success = false,
        message = ""
    }
    
    local ret = sys.call("/etc/init.d/openvpn start >/dev/null 2>&1")
    
    if ret == 0 then
        result.success = true
        result.message = "OpenVPN服务启动成功"
    else
        result.message = "OpenVPN服务启动失败"
    end
    
    http.write_json(result)
end

-- 停止OpenVPN服务
function stop_openvpn_service()
    local result = {
        success = false,
        message = "",
        debug_info = {}
    }
    
    table.insert(result.debug_info, "停止前状态检查开始")
    
    local service_output = sys.exec("/etc/init.d/openvpn status 2>/dev/null")
    table.insert(result.debug_info, "服务状态: " .. (service_output or "nil"))
    
    local pgrep_result = sys.exec("pgrep -f 'openvpn' 2>/dev/null | head -1")
    table.insert(result.debug_info, "pgrep结果: " .. (pgrep_result or "nil"))
    
    local ret = sys.call("/etc/init.d/openvpn stop >/dev/null 2>&1")
    
    if ret == 0 then
        sys.exec("sleep 1")
        
        local verify_output = sys.exec("/etc/init.d/openvpn status 2>/dev/null")
        table.insert(result.debug_info, "验证状态: " .. (verify_output or "nil"))
        
        local pgrep_verify = sys.exec("pgrep -f 'openvpn' 2>/dev/null | head -1")
        table.insert(result.debug_info, "验证pgrep: " .. (pgrep_verify or "nil"))
        
        if verify_output and verify_output:match("inactive") then
            result.success = true
            result.message = "OpenVPN服务已停止"
        elseif not pgrep_verify or pgrep_verify == "" then
            result.success = true
            result.message = "OpenVPN服务已停止"
        else
            local kill_ret = sys.call("killall -9 openvpn 2>/dev/null")
            table.insert(result.debug_info, "强制杀死结果: " .. tostring(kill_ret))
            
            if kill_ret == 0 then
                result.success = true
                result.message = "OpenVPN服务已强制停止"
            else
                result.message = "OpenVPN服务停止失败，请手动检查"
            end
        end
    else
        result.message = "OpenVPN服务停止失败"
    end
    
    http.write_json(result)
end

-- 断开客户端连接
function disconnect_client()
    local result = {
        success = false,
        message = "",
        debug_info = ""
    }
    
    local client_name = http.formvalue("client_name")
    local real_address = http.formvalue("real_address")
    local client_id = http.formvalue("client_id")
    
    nixio.syslog("info", "OpenVPN断开连接请求: client_name=" .. (client_name or "nil") .. 
                 ", real_address=" .. (real_address or "nil") .. 
                 ", client_id=" .. (client_id or "nil"))
    
    if not client_name or client_name == "" or client_name == "nil" then
        result.message = "客户端名称为空"
        http.write_json(result)
        return
    end
    
    local actual_client_id = client_id
    
    if actual_client_id then
        actual_client_id = actual_client_id:match("%d+") or actual_client_id
    end
    
    if not actual_client_id or actual_client_id == "" or actual_client_id == "nil" or actual_client_id == "N/A" then
        nixio.syslog("info", "Client ID无效，尝试通过management接口查找: " .. client_name)
        
        local management_ip, management_port = get_openvpn_management_config()
        
        if not management_ip or not management_port then
            result.message = "无法获取management接口配置"
            result.debug_info = "请检查OpenVPN配置中的management选项"
            http.write_json(result)
            return
        end
        
        local cmd = string.format("echo 'status 2' | /usr/bin/nc %s %s 2>&1 | grep 'CLIENT_LIST' | grep '%s'", management_ip, management_port, client_name)
        local status_output = sys.exec(cmd)
        
        if status_output and status_output ~= "" then
            nixio.syslog("info", "找到客户端信息: " .. status_output)
            
            for line in status_output:gmatch("[^\r\n]+") do
                if line:match("CLIENT_LIST") and line:match(client_name) then
                    local fields = util.split(line, ",")
                    if #fields >= 11 then
                        actual_client_id = fields[11] or "N/A"
                        nixio.syslog("info", "提取Client ID: " .. actual_client_id)
                        break
                    end
                end
            end
        else
            nixio.syslog("warn", "无法通过management接口找到客户端: " .. client_name)
        end
    end
    
    if actual_client_id then
        actual_client_id = actual_client_id:match("%d+") or actual_client_id
    end
    
    if not actual_client_id or actual_client_id == "" or actual_client_id == "N/A" then
        result.message = "无法找到客户端的Client ID"
        result.debug_info = "客户端名称: " .. client_name
        http.write_json(result)
        return
    end
    
    nixio.syslog("info", "准备断开连接: client=" .. client_name .. ", client_id=" .. actual_client_id)
    
    local management_ip, management_port = get_openvpn_management_config()
    
    if not management_ip or not management_port then
        result.message = "无法获取management接口配置"
        result.debug_info = "请检查OpenVPN配置中的management选项"
        http.write_json(result)
        return
    end
    
    local cmd = string.format("echo 'client-kill %s' | /usr/bin/nc %s %s 2>&1", actual_client_id, management_ip, management_port)
    nixio.syslog("info", "执行命令: " .. cmd)
    
    local output = sys.exec(cmd)
    nixio.syslog("info", "命令输出: " .. (output or "空"))
    
    if output and (output:match("SUCCESS") or output:match("INFO") or output:match("client%-kill")) then
        result.success = true
        result.message = "客户端 '" .. client_name .. "' 已断开"
        
        -- 将客户端添加到黑名单
        local blacklist_config = get_blacklist_config()
        if blacklist_config.enabled then
            add_client_to_blacklist_cn(client_name, blacklist_config.duration, "手动断开")
        end
        
        nixio.syslog("info", "断开连接成功: " .. client_name .. " (ID: " .. actual_client_id .. ")")
    else
        cmd = string.format("echo 'kill %s' | /usr/bin/nc %s %s 2>&1", actual_client_id, management_ip, management_port)
        nixio.syslog("info", "尝试第二种方法: " .. cmd)
        
        output = sys.exec(cmd)
        nixio.syslog("info", "命令输出: " .. (output or "空"))
        
        if output and (output:match("SUCCESS") or output:match("INFO") or output:match("kill")) then
            result.success = true
            result.message = "客户端 '" .. client_name .. "' 已断开"
            
            local blacklist_config = get_blacklist_config()
            if blacklist_config.enabled then
                add_client_to_blacklist_cn(client_name, blacklist_config.duration, "手动断开")
            end
            
            nixio.syslog("info", "使用kill命令断开连接成功: " .. client_name .. " (ID: " .. actual_client_id .. ")")
        else
            result.message = "无法断开客户端 '" .. client_name .. "' 的连接"
            result.debug_info = "Client ID: " .. actual_client_id .. ", 输出: " .. (output or "无输出")
            nixio.syslog("err", "断开连接失败: " .. result.message)
        end
    end
    
    http.write_json(result)
end

-- 通过客户端名查找Client ID
function find_client_id_by_name(client_name)
    if not client_name or client_name == "" then
        return nil
    end
    
    local management_ip, management_port = get_openvpn_management_config()
    
    if not management_ip or not management_port then
        return nil
    end
    
    local management_output = sys.exec(string.format("echo 'status 2' | nc %s %s 2>/dev/null | tail -n +3", management_ip, management_port))
    
    if management_output and management_output ~= "" then
        for line in management_output:gmatch("[^\r\n]+") do
            line = util.trim(line)
            
            if line:match("^CLIENT_LIST,") then
                local parts = util.split(line, ",")
                
                if #parts >= 13 then
                    local name = parts[2] or ""
                    if name == client_name then
                        local client_id = parts[11] or "N/A"
                        return client_id
                    end
                end
            end
        end
    end
    
    return nil
end

-- 查找客户端的Client ID（AJAX接口）
function find_client_id()
    local result = {
        success = false,
        client_id = "N/A",
        message = ""
    }
    
    local client_name = http.formvalue("client_name")
    
    if not client_name or client_name == "" then
        result.message = "客户端名称为空"
        http.write_json(result)
        return
    end
    
    local found_client_id = find_client_id_by_name(client_name)
    
    if found_client_id and found_client_id ~= "N/A" then
        result.success = true
        result.client_id = found_client_id
        result.message = "找到Client ID"
    else
        result.message = "未找到客户端的Client ID"
    end
    
    http.write_json(result)
end

-- 将客户端添加到黑名单（基于CN）
function add_client_to_blacklist_cn(client_cn, duration_seconds, reason)
    if not client_cn or client_cn == "" then return false end
    
    reason = reason or "手动断开"
    
    local blacklist_config = get_blacklist_config()
    duration_seconds = duration_seconds or blacklist_config.duration
    
    local current_time = os.time()
    local expiry_time = current_time + duration_seconds
    
    -- 读取现有黑名单
    local blacklist_file = blacklist_config.file
    local blacklist = {version = 1, entries = {}}
    
    if sys.call("test -f " .. blacklist_file .. " 2>/dev/null") == 0 then
        local blacklist_content = sys.exec("cat " .. blacklist_file .. " 2>/dev/null")
        if blacklist_content and blacklist_content ~= "" then
            local ok, data = pcall(json.parse, blacklist_content)
            if ok and data and data.entries then
                blacklist = data
            end
        end
    end
    
    -- 检查是否已存在
    local found = false
    for i, entry in ipairs(blacklist.entries) do
        if entry.cn == client_cn then
            blacklist.entries[i] = {
                cn = client_cn,
                added_time = current_time,
                expiry_time = expiry_time,
                duration = duration_seconds,
                reason = reason,
                added_time_formatted = os.date("%Y-%m-%d %H:%M:%S", current_time),
                expiry_time_formatted = os.date("%Y-%m-%d %H:%M:%S", expiry_time)
            }
            found = true
            break
        end
    end
    
    if not found then
        table.insert(blacklist.entries, {
            cn = client_cn,
            added_time = current_time,
            expiry_time = expiry_time,
            duration = duration_seconds,
            reason = reason,
            added_time_formatted = os.date("%Y-%m-%d %H:%M:%S", current_time),
            expiry_time_formatted = os.date("%Y-%m-%d %H:%M:%S", expiry_time)
        })
    end
    
    -- 保存黑名单
    return save_blacklist_cn(blacklist)
end

-- 保存黑名单到文件（基于CN）
function save_blacklist_cn(blacklist_data)
    local blacklist_config = get_blacklist_config()
    local blacklist_file = blacklist_config.file
    local json_data = json.stringify(blacklist_data, true)
    local temp_file = "/tmp/blacklist_cn.tmp"
    
    local temp_fd = io.open(temp_file, "w")
    if temp_fd then
        temp_fd:write(json_data)
        temp_fd:close()
        sys.exec("mv " .. temp_file .. " " .. blacklist_file .. " 2>/dev/null")
        sys.exec("chmod 644 " .. blacklist_file .. " 2>/dev/null")
        return true
    end
    return false
end

-- 获取客户端黑名单（基于CN）
function get_client_blacklist_cn()
    local blacklist_config = get_blacklist_config()
    local blacklist_file = blacklist_config.file
    local blacklist_entries = {}
    local current_time = os.time()
    local need_update = false
    
    -- 读取黑名单文件
    if sys.call("test -f " .. blacklist_file .. " 2>/dev/null") == 0 then
        local blacklist_content = sys.exec("cat " .. blacklist_file .. " 2>/dev/null")
        if blacklist_content and blacklist_content ~= "" then
            local ok, data = pcall(json.parse, blacklist_content)
            if ok and data and data.entries then
                for _, entry in ipairs(data.entries) do
                    if entry.expiry_time and entry.expiry_time > current_time then
                        entry.remaining_seconds = entry.expiry_time - current_time
                        entry.remaining_time = format_duration(entry.remaining_seconds)
                        entry.status = "active"
                        table.insert(blacklist_entries, entry)
                    else
                        need_update = true
                    end
                end
            end
        end
    end
    
    -- 如果需要更新，保存更新后的黑名单
    if need_update then
        local blacklist_data = {version = 1, entries = blacklist_entries}
        save_blacklist_cn(blacklist_data)
    end
    
    return blacklist_entries
end

-- 获取黑名单列表（AJAX接口）- 基于CN
function get_blacklist_cn()
    local result = {
        success = false,
        data = {},
        message = ""
    }
    
    local blacklist_config = get_blacklist_config()
    
    local blacklist = get_client_blacklist_cn()
    
    result.data = blacklist
    result.success = true
    
    http.write_json(result)
end

-- 从黑名单中移除客户端（基于CN）- AJAX接口
function remove_from_blacklist_cn()
    local client_cn = http.formvalue("cn")
    local result = {success = false, message = ""}
    
    if not client_cn or client_cn == "" then
        result.message = "客户端CN不能为空"
        http.write_json(result)
        return
    end
    
    local blacklist_config = get_blacklist_config()
    local blacklist_file = blacklist_config.file
    local blacklist = {version = 1, entries = {}}
    
    -- 读取现有黑名单
    if sys.call("test -f " .. blacklist_file .. " 2>/dev/null") == 0 then
        local blacklist_content = sys.exec("cat " .. blacklist_file .. " 2>/dev/null")
        if blacklist_content and blacklist_content ~= "" then
            local ok, data = pcall(json.parse, blacklist_content)
            if ok and data and data.entries then
                blacklist = data
            end
        end
    end
    
    -- 过滤掉要移除的客户端
    local new_entries = {}
    for _, entry in ipairs(blacklist.entries) do
        if entry.cn ~= client_cn then
            table.insert(new_entries, entry)
        end
    end
    
    blacklist.entries = new_entries
    
    -- 保存更新后的黑名单
    if save_blacklist_cn(blacklist) then
        result.success = true
        result.message = "客户端 '" .. client_cn .. "' 已从黑名单中移除"
        nixio.syslog("info", "OpenVPN黑名单: 从黑名单移除客户端 " .. client_cn)
    else
        result.message = "保存黑名单失败"
    end
    
    http.write_json(result)
end

-- 添加客户端到黑名单（基于CN）- AJAX接口
function add_client_to_blacklist()
    local result = {
        success = false,
        message = ""
    }
    
    local blacklist_config = get_blacklist_config()
        
    local cn = http.formvalue("cn")
    local duration = http.formvalue("duration")
    
    if not cn or cn == "" then
        result.message = "客户端CN不能为空"
        http.write_json(result)
        return
    end
    
    if not cn:match("^[%w_%-%.]+$") then
        result.message = "客户端CN格式不正确，只允许字母、数字、下划线、短横线和点"
        http.write_json(result)
        return
    end
    
    local duration_seconds = blacklist_config.duration
    if duration then
        if duration == "1min" then
            duration_seconds = 60
        elseif duration == "5min" then
            duration_seconds = 300
        elseif duration == "10min" then
            duration_seconds = 600
        elseif duration == "1hour" then
            duration_seconds = 3600
        elseif duration == "permanent" then
            duration_seconds = 31536000
        end
    end
    
    if add_client_to_blacklist_cn(cn, duration_seconds, "手动添加") then
        result.success = true
        result.message = "客户端 '" .. cn .. "' 已添加到黑名单"
        nixio.syslog("info", "OpenVPN黑名单: 添加客户端 " .. cn .. " 到黑名单")
    else
        result.message = "添加黑名单失败"
    end
    
    http.write_json(result)
end

-- 获取OpenVPN配置文件内容 (AJAX接口)
function get_openvpn_config()
    local result = {
        success = false,
        data = {},
        message = ""
    }
    
    local config_path = get_openvpn_config_path()
    
    if sys.call("test -f " .. config_path .. " 2>/dev/null") == 0 then
        local content = sys.exec("cat " .. config_path .. " 2>/dev/null")
        if content and content ~= "" then
            content = util.trim(content)
            
            local line_count = 0
            for _ in content:gmatch("[^\n]+") do
                line_count = line_count + 1
            end
            
            local char_count = #content
            
            result.data = {
                content = content,
                line_count = line_count,
                char_count = char_count
            }
            result.success = true
        else
            result.message = "配置文件为空"
        end
    else
        result.message = "配置文件不存在"
    end
    
    http.write_json(result)
end

-- 下载OpenVPN配置文件
function download_openvpn_config()
    local filename = get_openvpn_config_path()
    
    if sys.call("test -f " .. filename .. " 2>/dev/null") == 0 then
        local content = sys.exec("cat " .. filename .. " 2>/dev/null")
        
        http.header('Content-Type', 'text/plain')
        http.header('Content-Disposition', 'attachment; filename="openvpn-config.txt"')
        http.header('Content-Length', tostring(#content))
        
        http.write(content)
    else
        http.status(404, "File not found")
        http.write("配置文件不存在")
    end
end

-- 获取配置节详情 (AJAX接口)
function get_config_section()
    local result = {
        success = false,
        data = {},
        message = ""
    }
    
    local section_name = http.formvalue("section")
    
    if not section_name or section_name == "" then
        result.message = "未指定配置节名称"
        http.write_json(result)
        return
    end
    
    local config_lines = {}
    
    local uci_output = sys.exec("uci -q show openvpn." .. section_name .. " 2>/dev/null")
    if uci_output and uci_output ~= "" then
        for line in uci_output:gmatch("[^\r\n]+") do
            table.insert(config_lines, util.trim(line))
        end
        
        result.data = {
            section_name = section_name,
            config_lines = config_lines
        }
        result.success = true
    else
        result.message = "配置节不存在或为空"
    end
    
    http.write_json(result)
end

-- 保存OpenVPN配置 (AJAX接口)
function save_openvpn_config()
    local result = {
        success = false,
        message = "",
        redirect_url = nil
    }
    
    local config_content = http.formvalue("config")
    
    if not config_content or config_content == "" then
        result.message = "配置内容为空"
        http.write_json(result)
        return
    end
    
    if not config_content:match("config openvpn") then
        result.message = "配置必须包含config openvpn实例"
        http.write_json(result)
        return
    end
    
    local config_path = get_openvpn_config_path()
    
    -- 备份原配置文件
    local backup_file = config_path .. ".backup." .. os.time()
    local backup_cmd = string.format("cp %s %s 2>/dev/null", config_path, backup_file)
    sys.exec(backup_cmd)
    
    -- 保存新配置
    local temp_file = "/tmp/openvpn_config.tmp"
    
    local temp_fd = io.open(temp_file, "w")
    if temp_fd then
        temp_fd:write(config_content)
        temp_fd:close()
        
        local mv_cmd = string.format("mv %s %s", temp_file, config_path)
        local ret = sys.call(mv_cmd)
        
        if ret == 0 then
            result.success = true
            result.message = "配置保存成功"
        else
            result.message = "配置保存失败"
        end
    else
        result.message = "无法写入临时文件"
    end
    
    http.write_json(result)
end

-- 应用OpenVPN配置 (保存并重启服务) (AJAX接口)
function apply_openvpn_config()
    local result = {
        success = false,
        message = "",
        redirect_url = luci.dispatcher.build_url("admin/vpn/openvpn-admin/status")
    }
    
    local config_content = http.formvalue("config")
    
    if not config_content or config_content == "" then
        result.message = "配置内容为空"
        http.write_json(result)
        return
    end
    
    if not config_content:match("config openvpn") then
        result.message = "配置必须包含config openvpn实例"
        http.write_json(result)
        return
    end
    
    local config_path = get_openvpn_config_path()
    
    -- 备份原配置文件
    local backup_file = config_path .. ".backup." .. os.time()
    local backup_cmd = string.format("cp %s %s 2>/dev/null", config_path, backup_file)
    sys.exec(backup_cmd)
    
    -- 保存新配置
    local temp_file = "/tmp/openvpn_config.tmp"
    
    local temp_fd = io.open(temp_file, "w")
    if temp_fd then
        temp_fd:write(config_content)
        temp_fd:close()
        
        local mv_cmd = string.format("mv %s %s", temp_file, config_path)
        local ret = sys.call(mv_cmd)
        
        if ret == 0 then
            -- 应用配置
            local apply_cmd = "uci commit openvpn 2>/dev/null"
            local apply_ret = sys.call(apply_cmd)
            
            if apply_ret == 0 then
                -- 重启OpenVPN服务
                local restart_cmd = "/etc/init.d/openvpn restart 2>/dev/null"
                local restart_ret = sys.call(restart_cmd)
                
                if restart_ret == 0 then
                    result.success = true
                    result.message = "配置应用成功，OpenVPN服务已重启"
                else
                    result.message = "配置保存成功，但OpenVPN服务重启失败"
                    result.success = true
                end
            else
                result.message = "配置保存成功，但应用配置失败"
                result.success = true
            end
        else
            result.message = "配置保存失败"
        end
    else
        result.message = "无法写入临时文件"
    end
    
    http.write_json(result)
end

-- 生成客户端配置和证书 (AJAX接口)
function generate_client_config()
    local result = {
        success = false,
        message = "",
        filename = "",
        download_url = ""
    }
    
    local client_name = http.formvalue("client_name")
    local filename = http.formvalue("filename")
    
    if not client_name or client_name == "" then
        result.message = "客户端名称不能为空"
        http.write_json(result)
        return
    end
    
    if not client_name:match("^[%w_%-]+$") then
        result.message = "客户端名称格式不正确，只允许字母、数字、下划线、短横线"
        http.write_json(result)
        return
    end
    
    if filename and filename ~= "" then
        if not filename:match("^[%w_%-%.]+$") then
            result.message = "文件名格式不正确"
            http.write_json(result)
            return
        end
        if not filename:lower():match("%.ovpn$") then
            filename = filename .. ".ovpn"
        end
    else
        filename = client_name .. ".ovpn"
    end
    
    -- 创建临时目录（使用配置的临时目录）
    local config = get_admin_config()
    local temp_dir = config.temp_dir or "/tmp/openvpn-admin"
    sys.exec("mkdir -p " .. temp_dir .. " 2>/dev/null")
    
    -- 设置输出文件路径
    local output_file = temp_dir .. "/" .. filename
    
    -- 检查并生成客户端证书和配置
    local script_path = config.generate_client_script or "/etc/openvpn/generate-client.sh"
    
    -- 如果脚本不存在，创建它
    if sys.call("test -f " .. script_path .. " 2>/dev/null") ~= 0 then
        local cert_paths = get_cert_paths()
        local instance = get_openvpn_instance()
        
        local script_content = [[
#!/bin/sh
# OpenVPN客户端证书生成和配置文件生成脚本
# 参考genovpn.sh的原理，但不修改原文件

# 读取openvpn-admin配置
if [ -f /etc/config/openvpn-admin ]; then
    # 从配置文件中读取相关路径
    EASYRSA_DIR=$(uci -q get openvpn-admin.@settings[0].easyrsa_dir 2>/dev/null || echo "/etc/easy-rsa")
    EASYRSA_PKI=$(uci -q get openvpn-admin.@settings[0].easyrsa_pki 2>/dev/null || echo "/etc/easy-rsa/pki")
    OPENVPN_PKI=$(uci -q get openvpn-admin.@settings[0].openvpn_pki 2>/dev/null || echo "/etc/openvpn/pki")
    OPENVPN_INSTANCE=$(uci -q get openvpn-admin.@settings[0].openvpn_instance 2>/dev/null || echo "myvpn")
else
    # 默认值
    EASYRSA_DIR="/etc/easy-rsa"
    EASYRSA_PKI="$EASYRSA_DIR/pki"
    OPENVPN_PKI="/etc/openvpn/pki"
    OPENVPN_INSTANCE="myvpn"
fi

EASYRSA_VARS="$EASYRSA_DIR/vars-server"
TEMP_DIR="/tmp/openvpn-client"

# 参数检查
if [ -z "$1" ]; then
    echo "错误: 请指定客户端名称"
    exit 1
fi

CLIENT_NAME="$1"
OUTPUT_FILE="${2:-/tmp/$CLIENT_NAME.ovpn}"

# 创建临时目录
mkdir -p "$TEMP_DIR"

# 获取服务器配置 - 使用配置中的实例名称
DDNS=$(uci get openvpn.$OPENVPN_INSTANCE.ddns 2>/dev/null || echo "")
PORT=$(uci get openvpn.$OPENVPN_INSTANCE.port 2>/dev/null || echo "1194")
PROTO=$(uci get openvpn.$OPENVPN_INSTANCE.proto 2>/dev/null || echo "udp")

# 如果获取不到DDNS，尝试获取WAN IP
if [ -z "$DDNS" ] || [ "$DDNS" = "exmple.com" ]; then
    DDNS=$(uci get network.wan.ipaddr 2>/dev/null || echo "")
    if [ -z "$DDNS" ]; then
        DDNS=$(ip addr show br-lan 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -1)
    fi
fi

# 检查证书是否存在
check_client_cert() {
    local client_name="$1"
    
    # 检查是否已存在客户端证书
    if [ -f "$EASYRSA_PKI/issued/$client_name.crt" ] && \
       [ -f "$EASYRSA_PKI/private/$client_name.key" ]; then
        echo "客户端证书已存在: $client_name"
        return 0
    fi
    
    echo "客户端证书不存在: $client_name"
    return 1
}

# 生成客户端证书
generate_client_cert() {
    local client_name="$1"
    
    echo "正在生成客户端证书: $client_name"
    
    # 设置环境变量
    export EASYRSA_PKI="$EASYRSA_PKI"
    export EASYRSA_VARS_FILE="$EASYRSA_VARS"
    export EASYRSA_BATCH="1"
    
    # 切换到EasyRSA目录
    cd "$EASYRSA_DIR" || exit 1
    
    # 生成客户端证书（非交互模式）
    echo "正在生成证书..."
    if ! easyrsa build-client-full "$client_name" nopass >/dev/null 2>&1; then
        # 如果失败，尝试初始化PKI
        echo "初始化PKI并生成证书..."
        easyrsa init-pki
        easyrsa build-ca nopass
        easyrsa build-client-full "$client_name" nopass
    fi
    
    # 复制证书到OpenVPN目录
    mkdir -p "$OPENVPN_PKI"
    cp "$EASYRSA_PKI/ca.crt" "$OPENVPN_PKI/"
    cp "$EASYRSA_PKI/issued/$client_name.crt" "$OPENVPN_PKI/"
    cp "$EASYRSA_PKI/private/$client_name.key" "$OPENVPN_PKI/"
    
    echo "客户端证书生成完成: $client_name"
}

# 提取纯PEM格式证书（关键修复）
extract_pem_cert() {
    local cert_file="$1"
    
    if [ ! -f "$cert_file" ]; then
        echo "# 证书文件不存在"
        return 1
    fi
    
    # 提取BEGIN CERTIFICATE到END CERTIFICATE之间的内容
    # 使用sed提取纯PEM格式
    sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p' "$cert_file"
}

# 提取纯PEM格式密钥
extract_pem_key() {
    local key_file="$1"
    
    if [ ! -f "$key_file" ]; then
        echo "# 密钥文件不存在"
        return 1
    fi
    
    # 提取BEGIN PRIVATE KEY到END PRIVATE KEY之间的内容
    sed -n '/-----BEGIN.*PRIVATE KEY-----/,/-----END.*PRIVATE KEY-----/p' "$key_file"
}

# 生成.ovpn配置文件（修复后）
generate_ovpn_config() {
    local client_name="$1"
    local output_file="$2"
    
    echo "正在生成配置文件: $output_file"
    
    # 创建配置文件
    cat > "$output_file" <<EOF
##############################################
# OpenVPN 客户端配置文件
# 生成时间: $(date)
# 客户端: $CLIENT_NAME
# 服务器: $DDNS:$PORT
##############################################

client
dev tun
proto $PROTO
remote $DDNS $PORT
resolv-retry infinite
nobind
persist-key
persist-tun
verb 3

# 加密设置
cipher AES-256-GCM
auth SHA256

# TLS设置
remote-cert-tls server
key-direction 1

EOF

    # 添加CA证书 - 使用纯PEM格式
    echo "<ca>" >> "$output_file"
    if [ -f "$OPENVPN_PKI/ca.crt" ]; then
        extract_pem_cert "$OPENVPN_PKI/ca.crt" >> "$output_file"
    elif [ -f "$EASYRSA_PKI/ca.crt" ]; then
        extract_pem_cert "$EASYRSA_PKI/ca.crt" >> "$output_file"
    else
        echo "# CA证书不存在" >> "$output_file"
    fi
    echo "</ca>" >> "$output_file"

    # 添加客户端证书 - 使用纯PEM格式（关键修复）
    echo "<cert>" >> "$output_file"
    if [ -f "$OPENVPN_PKI/$client_name.crt" ]; then
        extract_pem_cert "$OPENVPN_PKI/$client_name.crt" >> "$output_file"
    elif [ -f "$EASYRSA_PKI/issued/$client_name.crt" ]; then
        extract_pem_cert "$EASYRSA_PKI/issued/$client_name.crt" >> "$output_file"
    else
        echo "# 客户端证书不存在" >> "$output_file"
    fi
    echo "</cert>" >> "$output_file"

    # 添加客户端密钥 - 使用纯PEM格式
    echo "<key>" >> "$output_file"
    if [ -f "$OPENVPN_PKI/$client_name.key" ]; then
        extract_pem_key "$OPENVPN_PKI/$client_name.key" >> "$output_file"
    elif [ -f "$EASYRSA_PKI/private/$client_name.key" ]; then
        extract_pem_key "$EASYRSA_PKI/private/$client_name.key" >> "$output_file"
    else
        echo "# 客户端密钥不存在" >> "$output_file"
    fi
    echo "</key>" >> "$output_file"

    # 添加附加配置（如果存在）
    if [ -f "/etc/openvpn-addon.conf" ]; then
        cat "/etc/openvpn-addon.conf" >> "$output_file"
    fi
    
    echo "配置文件生成完成: $output_file"
}

# 主执行流程
main() {
    echo "开始生成OpenVPN客户端配置"
    echo "客户端名称: $CLIENT_NAME"
    echo "输出文件: $OUTPUT_FILE"
    echo "服务器地址: $DDNS:$PORT ($PROTO)"
    echo "使用实例: $OPENVPN_INSTANCE"
    echo "EasyRSA目录: $EASYRSA_DIR"
    echo "PKI目录: $EASYRSA_PKI"
    
    # 检查证书是否存在
    if ! check_client_cert "$CLIENT_NAME"; then
        echo "证书不存在，开始生成..."
        if ! generate_client_cert "$CLIENT_NAME"; then
            echo "错误: 证书生成失败"
            exit 1
        fi
    fi
    
    # 生成.ovpn配置文件
    generate_ovpn_config "$CLIENT_NAME" "$OUTPUT_FILE"
    
    # 验证文件是否生成成功
    if [ -f "$OUTPUT_FILE" ]; then
        echo "生成成功！"
        echo "文件位置: $OUTPUT_FILE"
        echo "文件大小: $(du -h "$OUTPUT_FILE" | cut -f1)"
    else
        echo "错误: 文件生成失败"
        exit 1
    fi
}

# 执行主函数
main
]]
        
        local script_fd = io.open(script_path, "w")
        if script_fd then
            script_fd:write(script_content)
            script_fd:close()
            sys.exec("chmod +x " .. script_path .. " 2>/dev/null")
        else
            result.message = "无法创建生成脚本"
            http.write_json(result)
            return
        end
    end
    
    -- 执行生成脚本
    local cmd = string.format("%s '%s' '%s' 2>&1", script_path, client_name, output_file)
    local output = sys.exec(cmd)
    
    if sys.call("test -f " .. output_file .. " 2>/dev/null") == 0 then
        result.success = true
        result.message = "客户端配置生成成功"
        result.filename = filename
        result.download_url = luci.dispatcher.build_url("admin/vpn/openvpn-admin/download_client_config") .. "?filename=" .. filename .. "&client=" .. client_name
        
        nixio.syslog("info", "OpenVPN客户端配置生成成功: " .. client_name .. " -> " .. filename)
    else
        result.message = "配置文件生成失败: " .. (output or "未知错误")
    end
    
    http.write_json(result)
end

-- 重置所有证书 (AJAX接口)
function reset_all_certificates()
    local result = {
        success = false,
        message = "",
        debug_info = {}
    }
    
    local config = get_admin_config()
    local renew_script = config.renew_cert_script or "/etc/openvpn/renewcert.sh"
    
    local script_check = {}
    
    local file_exists = sys.call("test -f " .. renew_script .. " 2>/dev/null")
    table.insert(script_check, "file_exists: " .. (file_exists == 0 and "true" or "false"))
    
    if file_exists ~= 0 then
        result.message = "重置脚本不存在: " .. renew_script
        result.debug_info = script_check
        http.write_json(result)
        return
    end
    
    local file_perm = sys.exec("ls -la " .. renew_script .. " 2>/dev/null | head -1")
    table.insert(script_check, "file_permission: " .. (file_perm or "未知"))
    
    if file_perm and not file_perm:match("x") then
        local chmod_result = sys.call("chmod +x " .. renew_script .. " 2>/dev/null")
        table.insert(script_check, "chmod_result: " .. tostring(chmod_result))
        
        if chmod_result ~= 0 then
            result.message = "脚本没有执行权限，且无法添加权限"
            result.debug_info = script_check
            http.write_json(result)
            return
        end
    end
    
    local script_first_line = sys.exec("head -1 " .. renew_script .. " 2>/dev/null")
    table.insert(script_check, "script_first_line: " .. (script_first_line or "空"))
    
    if not script_first_line or not script_first_line:match("^#!") then
        result.message = "脚本文件格式不正确，不是有效的shell脚本"
        result.debug_info = script_check
        http.write_json(result)
        return
    end
    
    local start_time = os.time()
    table.insert(script_check, "start_time: " .. os.date("%Y-%m-%d %H:%M:%S", start_time))
    
    local log_file = "/tmp/renewcert.log"
    local cmd = renew_script .. " > " .. log_file .. " 2>&1 &"
    table.insert(script_check, "command: " .. cmd)
    
    sys.exec("echo '=== 证书重置开始 " .. os.date("%Y-%m-%d %H:%M:%S") .. " ===' > " .. log_file .. " 2>/dev/null")
    
    local ret = sys.call(cmd)
    table.insert(script_check, "return_code: " .. tostring(ret))
    
    sys.exec("sleep 1")
    
    local pid = sys.exec("pgrep -f 'renewcert.sh' 2>/dev/null | head -1")
    table.insert(script_check, "pid_after_1s: " .. (pid or "未找到"))
    
    if pid and pid ~= "" then
        result.success = true
        result.message = "证书重置脚本已启动成功 (PID: " .. util.trim(pid) .. ")"
        
        nixio.syslog("info", "OpenVPN证书重置脚本已启动，PID: " .. util.trim(pid))
        
        local status_content = "证书重置开始时间: " .. os.date("%Y-%m-%d %H:%M:%S", start_time) .. "\n"
        status_content = status_content .. "进程PID: " .. util.trim(pid) .. "\n"
        status_content = status_content .. "日志文件: " .. log_file .. "\n"
        
        local status_fd = io.open("/tmp/openvpn_status.log", "w")
        if status_fd then
            status_fd:write(status_content)
            status_fd:close()
        end
        
    elseif ret == 0 then
        result.success = true
        result.message = "证书重置脚本已执行"
        
        local log_content = sys.exec("tail -10 " .. log_file .. " 2>/dev/null")
        if log_content and log_content:match("error") then
            result.message = "脚本已执行，但可能存在错误，请检查日志"
            table.insert(script_check, "log_has_error: true")
        end
        
        nixio.syslog("info", "OpenVPN证书重置脚本已执行")
    else
        result.message = "证书重置脚本启动失败"
        table.insert(script_check, "execution_failed: true")
        
        local error_output = sys.exec(renew_script .. " 2>&1 | head -5")
        if error_output and error_output ~= "" then
            table.insert(script_check, "error_output: " .. error_output)
        end
        
        nixio.syslog("err", "OpenVPN证书重置脚本启动失败，返回码: " .. tostring(ret))
    end
    
    result.debug_info = script_check
    http.write_json(result)
end

-- 下载客户端配置文件 (AJAX接口)
function download_client_config()
    local result = {
        success = false,
        message = "",
        content = "",
        filename = ""
    }
    
    local client_name = http.formvalue("client")
    local filename = http.formvalue("filename") or (client_name and client_name .. ".ovpn")
    
    if not client_name or client_name == "" then
        result.message = "客户端名称不能为空"
        http.write_json(result)
        return
    end
    
    local config = get_admin_config()
    local temp_dir = config.temp_dir or "/tmp/openvpn-admin"
    local temp_file = temp_dir .. "/" .. (filename or client_name .. ".ovpn")
    local script_path = config.generate_client_script or "/etc/openvpn/generate-client.sh"
    
    if sys.call("test -f " .. script_path .. " 2>/dev/null") == 0 then
        -- 确保临时目录存在
        sys.exec("mkdir -p " .. temp_dir .. " 2>/dev/null")
        
        local cmd = script_path .. " '" .. client_name .. "' '" .. temp_file .. "' 2>&1"
        local output = sys.exec(cmd)
        
        if sys.call("test -f " .. temp_file .. " 2>/dev/null") == 0 then
            local content = sys.exec("cat " .. temp_file .. " 2>/dev/null")
            
            http.header('Content-Type', 'application/x-openvpn-profile')
            http.header('Content-Disposition', 'attachment; filename="' .. filename .. '"')
            http.header('Content-Length', tostring(#content))
            
            http.write(content)
            
            -- 清理临时文件
            sys.exec("rm -f " .. temp_file .. " 2>/dev/null")
            return
        else
            result.message = "配置文件生成失败: " .. output
        end
    else
        result.message = "生成脚本不存在"
    end
    
    http.write_json(result)
end

-- 获取OpenVPN UCI配置（AJAX接口）
function get_openvpn_uci_config()
    local result = {
        success = false,
        data = {},
        message = ""
    }
    
    local instance = get_openvpn_instance()
    
    if not instance or instance == "" then
        result.message = "OpenVPN实例名称未配置"
        http.write_json(result)
        return
    end
    
    -- 检查实例是否存在
    local exists = uci:get("openvpn", instance)
    if not exists then
        result.message = "OpenVPN实例不存在: " .. instance
        http.write_json(result)
        return
    end
    
    -- 获取所有可配置的选项
    local config_options = {
        -- 基本设置
        "enabled", "proto", "port", "ddns", "dev", "topology", "server",
        -- 证书路径
        "ca", "dh", "cert", "key",
        -- 高级设置
        "persist_key", "persist_tun", "user", "group", "max_clients", 
        "keepalive", "verb", "status", "log", "compress",
        -- management接口
        "management", "management_forget_disconnect",
        -- 黑名单脚本
        "client_connect", "script_security",
        -- IPv6地址
        "local"
    }
    
    -- 初始化配置数据
    local config_data = {}
    
    for _, option in ipairs(config_options) do
        local value = uci:get("openvpn", instance, option)
        if value then
            if option == "enabled" or option == "persist_key" or option == "persist_tun" or 
               option == "management_forget_disconnect" then
                config_data[option] = (value == "1")
            else
                config_data[option] = value
            end
        else
            -- 设置默认值
            if option == "enabled" then
                config_data[option] = false  -- 默认关闭
            elseif option == "proto" then
                config_data[option] = "udp"
            elseif option == "port" then
                config_data[option] = "1194"
            elseif option == "ddns" then
                config_data[option] = ""
            elseif option == "dev" then
                config_data[option] = "tun"
            elseif option == "topology" then
                config_data[option] = "subnet"
            elseif option == "server" then
                config_data[option] = "10.8.0.0 255.255.255.0"
            elseif option == "compress" then
                config_data[option] = ""
            elseif option == "max_clients" then
                config_data[option] = "10"
            elseif option == "keepalive" then
                config_data[option] = "10 120"
            elseif option == "verb" then
                config_data[option] = "3"
            elseif option == "user" then
                config_data[option] = "nobody"
            elseif option == "group" then
                config_data[option] = "nogroup"
            elseif option == "status" then
                config_data[option] = "/var/log/openvpn_status.log"
            elseif option == "log" then
                config_data[option] = "/tmp/openvpn.log"
            elseif option == "persist_key" then
                config_data[option] = true
            elseif option == "persist_tun" then
                config_data[option] = true
            elseif option == "management_forget_disconnect" then
                config_data[option] = true
            else
                config_data[option] = ""
            end
        end
    end
    
    -- 获取push列表 - 正确的方式
    local push_options = {}
    local all_config = uci:get_all("openvpn", instance)
    if all_config then
        for key, value in pairs(all_config) do
            if key:match("^push") and type(value) == "string" and value ~= "" then
                table.insert(push_options, value)
            elseif key == "push" and type(value) == "table" then
                -- 如果是列表格式
                for _, v in ipairs(value) do
                    if v and v ~= "" then
                        table.insert(push_options, v)
                    end
                end
            end
        end
    end
    
    config_data.push = push_options
    
    -- 检查management接口是否启用
    local management_value = uci:get("openvpn", instance, "management")
    config_data.enable_management = management_value and management_value ~= ""
    
    -- 检查黑名单是否启用
    local client_connect_value = uci:get("openvpn", instance, "client_connect")
    config_data.enable_blacklist = client_connect_value and client_connect_value ~= ""
    
    -- 检查IPv6是否启用
    local local_value = uci:get("openvpn", instance, "local")
    config_data.enable_ipv6 = local_value and local_value ~= ""
    
    -- 如果黑名单启用，确保script_security有值
    if config_data.enable_blacklist and (not config_data.script_security or config_data.script_security == "") then
        config_data.script_security = "3"
    end
    
    result.data = config_data
    result.success = true
    
    http.write_json(result)
end

-- 保存OpenVPN UCI配置（AJAX接口）- 已添加防火墙端口同步功能
function save_openvpn_uci_config()
    local result = {
        success = false,
        message = ""
    }
    
    local instance = get_openvpn_instance()
    
    if not instance or instance == "" then
        result.message = "OpenVPN实例名称未配置"
        http.write_json(result)
        return
    end
    
    -- 保存原有端口，用于比较是否需要更新防火墙
    local old_port = nil
    local old_proto = nil
    local exists = uci:get("openvpn", instance)
    if exists then
        old_port = uci:get("openvpn", instance, "port")
        old_proto = uci:get("openvpn", instance, "proto")
    end
    
    -- 检查实例是否存在，如果不存在则创建
    local exists = uci:get("openvpn", instance)
    if not exists then
        local ok, err = pcall(function()
            uci:section("openvpn", "openvpn", instance, {})
        end)
        if not ok then
            result.message = "创建实例失败: " .. tostring(err)
            http.write_json(result)
            return
        end
    end
    
    -- 处理基本配置项
    local config_fields = {
        "enabled", "proto", "port", "ddns", "dev", "topology", "server",
        "ca", "dh", "cert", "key", "persist_key", "persist_tun", "user",
        "group", "max_clients", "keepalive", "verb", "status", "log",
        "compress"
    }
    
    for _, field in ipairs(config_fields) do
        local value = http.formvalue(field)
        if value ~= nil then
            if field == "enabled" or field == "persist_key" or field == "persist_tun" then
                value = (value == "1" or value == "true" or value == "on") and "1" or "0"
            end
            local ok, err = pcall(function()
                uci:set("openvpn", instance, field, value)
            end)
            if not ok then
                result.message = "设置字段 " .. field .. " 失败: " .. tostring(err)
                http.write_json(result)
                return
            end
        end
    end
    
    -- 处理IPv6地址
    local enable_ipv6 = http.formvalue("enable_ipv6")
    local local_address = http.formvalue("local")
    if enable_ipv6 and enable_ipv6 == "1" and local_address and local_address ~= "" then
        local ok, err = pcall(function()
            uci:set("openvpn", instance, "local", local_address)
        end)
        if not ok then
            result.message = "设置IPv6地址失败: " .. tostring(err)
            http.write_json(result)
            return
        end
    else
        -- 禁用IPv6时删除local选项
        local ok, err = pcall(function()
            uci:delete("openvpn", instance, "local")
        end)
        if not ok then
            -- 如果删除失败，可能该选项不存在，这不算错误
        end
    end
    
    -- 处理push列表（先清除所有现有的push）
    local ok, all_config = pcall(function()
        return uci:get_all("openvpn", instance)
    end)
    
    if ok and all_config then
        for key, _ in pairs(all_config) do
            if key:match("^push") then
                local ok, err = pcall(function()
                    uci:delete("openvpn", instance, key)
                end)
                if not ok then
                    result.message = "删除push配置 " .. key .. " 失败: " .. tostring(err)
                    http.write_json(result)
                    return
                end
            end
        end
    end
    
    -- 添加新的push列表 - 修复push配置保存问题
    -- 收集所有push配置
    local push_list = {}
    local push_index = 0
    while true do
        local push_value_raw = http.formvalue("push_" .. push_index)
        if not push_value_raw or push_value_raw == "" then
            break
        end
        
        -- 从原始值中提取实际的push内容
        -- 原始值格式: list push 'route 192.168.100.0 255.255.255.0'
        -- 我们需要提取: 'route 192.168.100.0 255.255.255.0'
        local push_content = push_value_raw:match("list push%s+'([^']+)'")
        if not push_content then
            -- 尝试另一种匹配方式
            push_content = push_value_raw:match("list push%s+\"([^\"]+)\"")
        end
        
        if not push_content then
            -- 如果没有匹配到引号内容，尝试匹配整个字符串（去除非引号部分）
            -- 移除开头的'list push'和空格
            push_content = push_value_raw:gsub("^list push%s+", "")
            -- 移除可能的引号
            push_content = push_content:gsub("^['\"]", ""):gsub("['\"]$", "")
        end
        
        if push_content and push_content ~= "" then
            table.insert(push_list, push_content)
        else
            -- 如果无法解析，使用原始值（但移除list push前缀）
            push_content = push_value_raw:gsub("^list push%s+", "")
            if push_content and push_content ~= "" then
                table.insert(push_list, push_content)
            end
        end
        
        push_index = push_index + 1
    end
    
    -- 如果有push配置，添加到UCI配置中
    if #push_list > 0 then
        for i, push_content in ipairs(push_list) do
            local ok, err = pcall(function()
                -- 使用uci:add_list添加push配置项
                uci:set_list("openvpn", instance, "push", push_list)
            end)
            if not ok then
                result.message = "添加push配置失败: " .. tostring(err)
                http.write_json(result)
                return
            end
        end
    end
    
    -- 处理management接口
    local enable_management = http.formvalue("enable_management")
    if enable_management and enable_management == "1" then
        local management_address = http.formvalue("management_address") or "127.0.0.1"
        local management_port = http.formvalue("management_port") or "7505"
        if management_address and management_port then
            local ok, err = pcall(function()
                uci:set("openvpn", instance, "management", management_address .. " " .. management_port)
            end)
            if not ok then
                result.message = "设置management接口失败: " .. tostring(err)
                http.write_json(result)
                return
            end
        end
        
        local management_forget = http.formvalue("management_forget_disconnect")
        if management_forget then
            local value = (management_forget == "1" or management_forget == "true" or management_forget == "on") and "1" or "0"
            local ok, err = pcall(function()
                uci:set("openvpn", instance, "management_forget_disconnect", value)
            end)
            if not ok then
                result.message = "设置management_forget_disconnect失败: " .. tostring(err)
                http.write_json(result)
                return
            end
        else
            -- 默认启用
            local ok, err = pcall(function()
                uci:set("openvpn", instance, "management_forget_disconnect", "1")
            end)
            if not ok then
                result.message = "设置management_forget_disconnect默认值失败: " .. tostring(err)
                http.write_json(result)
                return
            end
        end
    else
        -- 禁用时删除management和management_forget_disconnect
        local ok1, err1 = pcall(function()
            uci:delete("openvpn", instance, "management")
        end)
        local ok2, err2 = pcall(function()
            uci:delete("openvpn", instance, "management_forget_disconnect")
        end)
        
        if not ok1 then
            -- 如果删除失败，可能该选项不存在，这不算错误
        end
        if not ok2 then
            -- 如果删除失败，可能该选项不存在，这不算错误
        end
    end
    
    -- 处理黑名单
    local enable_blacklist = http.formvalue("enable_blacklist")
    if enable_blacklist and enable_blacklist == "1" then
        local client_connect = http.formvalue("client_connect") or "/etc/openvpn/client-connect-cn.sh"
        local script_security = http.formvalue("script_security") or "3"
        
        local ok1, err1 = pcall(function()
            uci:set("openvpn", instance, "client_connect", client_connect)
        end)
        local ok2, err2 = pcall(function()
            uci:set("openvpn", instance, "script_security", script_security)
        end)
        
        if not ok1 then
            result.message = "设置client_connect失败: " .. tostring(err1)
            http.write_json(result)
            return
        end
        if not ok2 then
            result.message = "设置script_security失败: " .. tostring(err2)
            http.write_json(result)
            return
        end
    else
        -- 禁用时删除黑名单相关配置
        local ok1, err1 = pcall(function()
            uci:delete("openvpn", instance, "client_connect")
        end)
        local ok2, err2 = pcall(function()
            uci:delete("openvpn", instance, "script_security")
        end)
        
        if not ok1 then
            -- 如果删除失败，可能该选项不存在，这不算错误
        end
        if not ok2 then
            -- 如果删除失败，可能该选项不存在，这不算错误
        end
    end
    
    -- 提交更改
    local save_ok, save_err = pcall(function()
        return uci:save("openvpn")
    end)
    
    if save_ok then
        local commit_ok, commit_err = pcall(function()
            return uci:commit("openvpn")
        end)
        
        if commit_ok then
            -- 获取新配置的端口
            local new_port = http.formvalue("port") or uci:get("openvpn", instance, "port") or old_port
            
            -- 检查IPv6是否启用
            local enable_ipv6 = http.formvalue("enable_ipv6")
            if enable_ipv6 and enable_ipv6 == "1" then
                -- 获取IPv6脚本配置
                local config = get_admin_config()
                
                if config.ipv6_script_enabled then
                    -- 运行IPv6脚本
                    local script_result = run_ipv6_script_if_enabled()
                    if script_result == false then
                        result.message = result.message .. " (警告：IPv6脚本不存在)"
                    elseif script_result == true then
                        result.message = result.message .. " (IPv6脚本已执行)"
                    end
                    
                    -- 更新IPv6定时任务
                    update_ipv6_cron_job()
                end
            else
                -- 如果禁用了IPv6，也更新定时任务（会移除IPv6定时任务）
                update_ipv6_cron_job()
            end
            
            -- 如果端口发生变化，或者之前没有端口但现在有了，则更新防火墙规则
            if new_port then
                if old_port and new_port ~= old_port then
                    -- 端口变化，更新防火墙规则
                    local firewall_result = update_firewall_port(old_port, new_port)
                    if firewall_result then
                        result.message = "配置保存成功，OpenVPN服务已重启，防火墙端口已从 " .. old_port .. " 更新为 " .. new_port
                    else
                        result.message = "配置保存成功，OpenVPN服务已重启，但防火墙端口更新失败"
                    end
                elseif not old_port and new_port then
                    -- 之前没有端口配置，现在有端口，添加防火墙规则
                    local firewall_result = add_firewall_port(new_port)
                    if firewall_result then
                        result.message = "配置保存成功，OpenVPN服务已重启，防火墙已添加端口 " .. new_port .. " 规则"
                    else
                        result.message = "配置保存成功，OpenVPN服务已重启，但防火墙规则添加失败"
                    end
                else
                    -- 端口未变化，检查防火墙规则是否存在
                    local rule_exists, rule_section = check_firewall_rule()
                    if not rule_exists then
                        -- 防火墙规则不存在，创建它
                        local firewall_result = add_firewall_port(new_port)
                        if firewall_result then
                            result.message = "配置保存成功，OpenVPN服务已重启，防火墙已添加端口 " .. new_port .. " 规则"
                        else
                            result.message = "配置保存成功，OpenVPN服务已重启，但防火墙规则创建失败"
                        end
                    else
                        result.message = "配置保存成功，OpenVPN服务已重启"
                    end
                end
            else
                result.message = "配置保存成功，OpenVPN服务已重启（未指定端口）"
            end
            
            -- 重启OpenVPN服务
            local ret = sys.call("/etc/init.d/openvpn restart >/dev/null 2>&1")
            
            if ret ~= 0 then
                result.message = result.message .. "，但OpenVPN服务重启失败，请手动重启"
            end
            
            result.success = true
        else
            result.message = "提交配置失败: " .. tostring(commit_err)
        end
    else
        result.message = "保存配置失败: " .. tostring(save_err)
    end
    
    http.write_json(result)
end

-- 工具函数：格式化字节数
function format_bytes(bytes)
    if not bytes or bytes == 0 then return "0 B" end
    local units = {"B", "KB", "MB", "GB"}
    local i = 1
    while bytes >= 1024 and i < #units do
        bytes = bytes / 1024
        i = i + 1
    end
    return string.format("%.2f %s", bytes, units[i])
end

-- 计算数据总计（接收+发送）
function calculate_total_data(bytes_received, bytes_sent)
    if not bytes_received then bytes_received = 0 end
    if not bytes_sent then bytes_sent = 0 end
    return format_bytes(bytes_received + bytes_sent)
end