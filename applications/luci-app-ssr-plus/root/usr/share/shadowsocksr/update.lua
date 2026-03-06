#!/usr/bin/lua

------------------------------------------------
-- This file is part of the luci-app-ssr-plus update.lua
-- By Mattraks
------------------------------------------------
require "luci.sys"
require "luci.model.uci"
local icount = 0
local args = arg[1]
local uci = luci.model.uci.cursor()
local TMP_DNSMASQ_PATH = "/tmp/dnsmasq.d/dnsmasq-ssrplus.d"
local TMP_PATH = "/var/etc/ssrplus"
-- match comments/title/whitelist/ip address/excluded_domain
local comment_pattern = "^[!\\[@]+"
local ip_pattern = "^%d+%.%d+%.%d+%.%d+"
local domain_pattern = "([%w%-%_]+%.[%w%.%-%_]+)[%/%*]*"
local excluded_domain = {"apple.com", "sina.cn", "sina.com.cn", "baidu.com", "byr.cn", "jlike.com", "weibo.com", "zhongsou.com", "youdao.com", "sogou.com", "so.com", "soso.com", "aliyun.com", "taobao.com", "jd.com", "qq.com"}
-- gfwlist parameter
local mydnsip = '127.0.0.1'
local mydnsport = '5335'
local ipsetname = 'gfwlist'
local bc = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
-- base64decoding
local function base64_dec(data)
	data = string.gsub(data, '[^' .. bc .. '=]', '')
	return (data:gsub('.', function(x)
		if (x == '=') then
			return ''
		end
		local r, f = '', (bc:find(x) - 1)
		for i = 6, 1, -1 do
			r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and '1' or '0')
		end
		return r;
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if (#x ~= 8) then
			return ''
		end
		local c = 0
		for i = 1, 8 do
			c = c + (x:sub(i, i) == '1' and 2 ^ (8 - i) or 0)
		end
		return string.char(c)
	end))
end
-- check excluded domain
local function check_excluded_domain(value)
	for k, v in ipairs(excluded_domain) do
		if value:find(v) then
			return true
		end
	end
end
-- gfwlist转码至dnsmasq格式
local function generate_gfwlist(type)
	local domains = {}
	local out = io.open("/tmp/ssr-update." .. type, "w")
	for line in io.lines("/tmp/ssr-update.tmp") do
		if not (string.find(line, comment_pattern) or string.find(line, ip_pattern) or check_excluded_domain(line)) then
			local start, finish, match = string.find(line, domain_pattern)
			if (start) then
				domains[match] = true
			end
		end
	end
	for k, v in pairs(domains) do
		out:write(string.format("server=/%s/%s#%s\n", k, mydnsip, mydnsport))
		out:write(string.format("ipset=/%s/%s\n", k, ipsetname))
	end
	out:close()
	os.remove("/tmp/ssr-update.tmp")
end

-- adblock转码至dnsmasq格式
local function generate_adblock(type)
	local domains = {}
	local out = io.open("/tmp/ssr-update." .. type, "w")
	for line in io.lines("/tmp/ssr-update.tmp") do
		if not (string.find(line, comment_pattern)) then
			local start, finish, match = string.find(line, domain_pattern)
			if (start) then
				domains[match] = true
			end
		end
	end
	for k, v in pairs(domains) do
		out:write(string.format("address=/%s/\n", k))
	end
	out:close()
	os.remove("/tmp/ssr-update.tmp")
end

local log = function(...)
	if args then
		print("{ret=" .. table.concat({...}, ",retcount=") .. "}")
	else
		print(os.date("%Y-%m-%d %H:%M:%S ") .. table.concat({...}, " "))
	end
end

local function get_curl_command(url, output_path)
	local domain = string.match(url, "://(.-)/") or ""
	if domain == "" then
		return "curl --connect-timeout 5 -m 120 --ipv4 -kfSLo " .. output_path .. " " .. url
	end

	-- Run nslookup 119.29.29.29 and parse with awk strictly preserving IPv4
	local awk_cmd = string.format("nslookup '%s' 119.29.29.29 2>/dev/null | awk -v dns='119.29.29.29' '/Address/ {for(i=1; i<=NF; i++) {if ($i ~ /^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$/ && $i != dns && $i != \"127.0.0.1\" && $i != \"0.0.0.0\") {ip=$i}}} END {print ip}'", domain)
	local handle = io.popen(awk_cmd)
	local ip = handle:read("*a")
	handle:close()
	ip = ip:gsub("%s+", "") -- strip newlines/spaces
	
	local resolve_str = ""
	if ip and ip ~= "" then
		resolve_str = string.format("--resolve %s:443:%s --resolve %s:80:%s", domain, ip, domain, ip)
	else
		-- fallback execution, still forcing resolve syntax even if empty to actively fail instead of leaking DNS
		resolve_str = string.format("--resolve %s:443:119.29.29.29 --resolve %s:80:119.29.29.29", domain, domain)
	end
	
	-- [B-003-Fix] Resolve GitHub redirect domains to prevent curl timeout
	if domain == "github.com" or domain == "raw.githubusercontent.com" then
		local extra_domains = {"release-assets.githubusercontent.com", "objects.githubusercontent.com"}
		for _, ed in ipairs(extra_domains) do
			local e_awk_cmd = string.format("nslookup '%s' 119.29.29.29 2>/dev/null | awk -v dns='119.29.29.29' '/Address/ {for(i=1; i<=NF; i++) {if ($i ~ /^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$/ && $i != dns && $i != \"127.0.0.1\" && $i != \"0.0.0.0\") {ip=$i}}} END {print ip}'", ed)
			local e_handle = io.popen(e_awk_cmd)
			local e_ip = e_handle:read("*a")
			e_handle:close()
			e_ip = e_ip:gsub("%s+", "")
			if e_ip and e_ip ~= "" then
				resolve_str = resolve_str .. string.format(" --resolve %s:443:%s --resolve %s:80:%s", ed, e_ip, ed, e_ip)
			else
				resolve_str = resolve_str .. string.format(" --resolve %s:443:119.29.29.29 --resolve %s:80:119.29.29.29", ed, ed)
			end
		end
	end

	return string.format("curl %s --connect-timeout 5 -m 120 --ipv4 -kfSLo %s %s", resolve_str, output_path, url)
end

local function update(url, file, type, file2)
	local Num = 1
	local refresh_cmd = get_curl_command(url, "/tmp/ssr-update." .. type)
	local sret = luci.sys.call(refresh_cmd)
	if sret == 0 then
		if type == "gfw_data" then
			local gfwlist = io.open("/tmp/ssr-update." .. type, "r")
			local decode = gfwlist:read("*a")
			if not decode:find("google") then
				decode = base64_dec(decode)
			end
			gfwlist:close()
			-- 写回gfwlist
			gfwlist = io.open("/tmp/ssr-update.tmp", "w")
			gfwlist:write(decode)
			gfwlist:close()
			generate_gfwlist(type)
			Num = 2
		end
		if type == "ad_data" then
			local adblock = io.open("/tmp/ssr-update." .. type, "r")
			local decode = adblock:read("*a")
			if decode:find("address=") then
				adblock:close()
			else
				adblock:close()
				-- 写回adblock
				adblock = io.open("/tmp/ssr-update.tmp", "w")
				adblock:write(decode)
				adblock:close()
				generate_adblock(type)
			end
		end
		local new_md5 = luci.sys.exec("echo -n $([ -f '/tmp/ssr-update." .. type .. "' ] && md5sum /tmp/ssr-update." .. type .. " | awk '{print $1}')")
		local old_md5 = luci.sys.exec("echo -n $([ -f '" .. file .. "' ] && md5sum " .. file .. " | awk '{print $1}')")
		if new_md5 == old_md5 then
			if args then
				log(1)
			else
				log("你已经是最新数据，无需更新！")
			end
		else
			icount = luci.sys.exec("cat /tmp/ssr-update." .. type .. " | wc -l")
			if tonumber(icount) < 10 then
				log("诊断日志 [UPDATE-B167-①] 检查数据完备性: 行数异常 icount=" .. tostring(icount))
				if args then
					log(-1)
				else
					log("更新失败！下载的数据不完整或为空，禁止覆盖旧数据！")
				end
			else
				log("诊断日志 [UPDATE-B167-②] 检查数据完备性: 行数正常 icount=" .. tostring(icount))
				luci.sys.exec("cp -f /tmp/ssr-update." .. type .. " " .. file .. ".tmp && mv -f " .. file .. ".tmp " .. file)
				if file2 then
					luci.sys.exec("cp -f /tmp/ssr-update." .. type .. " " .. file2 .. ".tmp && mv -f " .. file2 .. ".tmp " .. file2)
				end
				if type == "gfw_data" or type == "ad_data" then
					luci.sys.call("/usr/share/shadowsocksr/gfw2ipset.sh")
				else
					luci.sys.call("/usr/share/shadowsocksr/chinaipset.sh " .. TMP_PATH .. "/china_ssr.txt")
				end
				if args then
					log(0, tonumber(icount) / Num)
				else
					log("更新成功！ 新的总纪录数：" .. tostring(tonumber(icount) / Num))
				end
			end
		end
	else
		if args then
			log(-1)
		else
			log("更新失败！")
		end
	end
	os.remove("/tmp/ssr-update." .. type)
end

if args then
	if args == "gfw_data" then
		update(uci:get_first("shadowsocksr", "global", "gfwlist_url"), "/etc/ssrplus/gfw_list.conf", args, TMP_DNSMASQ_PATH .. "/gfw_list.conf")
		os.exit(0)
	end
	if args == "ip_data" then
		update(uci:get_first("shadowsocksr", "global", "chnroute_url"), "/etc/ssrplus/china_ssr.txt", args, TMP_PATH .. "/china_ssr.txt")
		os.exit(0)
	end
	if args == "ad_data" then
		update(uci:get_first("shadowsocksr", "global", "adblock_url"), "/etc/ssrplus/ad.conf", args, TMP_DNSMASQ_PATH .. "/ad.conf")
		os.exit(0)
	end
	if args == "nfip_data" then
		update(uci:get_first("shadowsocksr", "global", "nfip_url"), "/etc/ssrplus/netflixip.list", args)
		os.exit(0)
	end
else
	log("正在更新【GFW列表】数据库")
	update(uci:get_first("shadowsocksr", "global", "gfwlist_url"), "/etc/ssrplus/gfw_list.conf", "gfw_data", TMP_DNSMASQ_PATH .. "/gfw_list.conf")
	log("正在更新【国内IP段】数据库")
	update(uci:get_first("shadowsocksr", "global", "chnroute_url"), "/etc/ssrplus/china_ssr.txt", "ip_data", TMP_PATH .. "/china_ssr.txt")
	if uci:get_first("shadowsocksr", "global", "adblock", "0") == "1" then
		log("正在更新【广告屏蔽】数据库")
		update(uci:get_first("shadowsocksr", "global", "adblock_url"), "/etc/ssrplus/ad.conf", "ad_data", TMP_DNSMASQ_PATH .. "/ad.conf")
	end
	-- log("正在更新【Netflix IP段】数据库")
	-- update(uci:get_first("shadowsocksr", "global", "nfip_url"), "/etc/ssrplus/netflixip.list", "nfip_data")
end
