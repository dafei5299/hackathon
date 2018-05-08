#!/usr/bin/env lua

local caches = ngx.shared.ngxcache
--local socket = require "socket"
local json = require 'cjson'
local cookie = require 'lib.cookie.cookie'
local common = {}

-- 从调整缓存中获取配置项
function common:get_config(key)
	return caches:get(key)
end

--获取所有请求参数
function common:args()
	local args = {
		GET = {},
		POST = {},
	}
	args.GET = ngx.req.get_uri_args()
	ngx.req.read_body()
   	args.POST = ngx.req.get_post_args()
  	return args
end

function common:merge( tDest, tSrc )
    for k, v in pairs( tSrc ) do
        tDest[k] = v
    end
end

function common:merge_args()
	local GET = ngx.req.get_uri_args()
	ngx.req.read_body()
   	local POST = ngx.req.get_post_args()
   	common:merge(GET, POST)
   	return GET
end

function common:requestIP() 
    -- ip限制
    local remote_addr = ngx.req.get_headers()["X-Real-IP"]  
    if remote_addr == nil then  
       remote_addr = ngx.req.get_headers()["x_forwarded_for"] 
    end  
    if remote_addr == nil then  
       remote_addr = ngx.var.remote_addr  
    end
    return remote_addr
end


-- url编码解码
function common:decodeURI(s)
    s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
    return s
end
function encodeURI(s)
    s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
    return string.gsub(s, " ", "+")
end

-- 获取毫秒时间戳
function common:getms()
	-- 通过socket获取毫秒更精确
	-- local ms = socket:gettime() * 1000
	-- if string.len(ms) > 13 then
	-- 	ms = string.sub(ms,0,13)
	-- end

	-- 通过nginx获取的效率高
	local ms = ngx.now() * 1000  
	return ms
end

-- 返回值格式封装
function common:result_format(code,value)
	local result = {
		code = code,
		data = value
	}
	return json.encode(result)
end
-- 生成唯一请求ID
function common:processid()
	local process_string = ngx.var.remote_addr .. ngx.var.remote_port .. ngx.var.server_addr .. ngx.var.server_port .. ngx.now()
	return ngx.md5(process_string)
end

-- 拆分字符串
function common:split(str, delim, maxNb)
	-- Eliminate bad cases...
	if string.find(str, delim) == nil then
		return { str }
	end
	if maxNb == nil or maxNb < 1 then
		maxNb = 0    -- No limit
	end
	local result = {}
	local pat = "(.-)" .. delim .. "()"
	local nb = 0
	local lastPos
	for part, pos in string.gfind(str, pat) do
		nb = nb + 1
		result[nb] = part
		lastPos = pos
		if nb == maxNb then break end
	end
	-- Handle the last field
	if nb ~= maxNb then
		result[nb + 1] = string.sub(str, lastPos)
	end
	return result
end

-- 拆分字符串 chunk
function common:new_split(szFullString, szSeparator)
	local nFindStartIndex = 1
	local nSplitIndex = 1
	local nSplitArray = {}
	while true do
		local nFindLastIndex = string.find(szFullString, szSeparator, nFindStartIndex)
		if not nFindLastIndex then
			nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, string.len(szFullString))
			break
		end
		nSplitArray[nSplitIndex] = string.sub(szFullString, nFindStartIndex, nFindLastIndex - 1)
		nFindStartIndex = nFindLastIndex + string.len(szSeparator)
		nSplitIndex = nSplitIndex + 1
	end
	return nSplitArray
end

-- value是否包含在table里
function common:is_include(tab, value)
    for _, v in pairs(tab) do
      if v == value then
          return true
      end
    end
    return false
end

-- 判断一个table中是否有需要的key
function common:search_table(table, args)
	if type(table) ~= 'table' or not args then
		return nil
	end

	local table_v = table
	for k, v in ipairs(args) do
		if not table_v[v] then
			return nil
		end
		table_v = table_v[v]
	end
	return table_v
end

function common:sort_key(table)
    local key_table = {}  
    --取出所有的键  
    for key, _ in pairs(table) do  
        table.insert(key_table,key)  
    end  
    --对所有键进行排序  
    table.sort(key_table)

    for _,key in pairs(key_table) do  
        print(key, table[key])  
    end
end

function common:user_identity()
    local useragent = ngx.var.http_user_agent
    local remote_addr = common:requestIP()
    return useragent .. remote_addr;
end

function common:print_debug_log(debug_table)
	if next(debug_table) ~= nil then
		for m,k in pairs(debug_table) do
			ngx.say(k)
		end
	end
end

return common