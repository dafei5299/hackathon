#!/usr/bin/env lua

local api = ngx.var.api

local common = require "lib.common"
local cache = ngx.shared.ngxcache
local common = common:args()

local result = "no method"
ngx.header['Content-type'] = "text/html;charset=utf-8"
if api == "set" then
	result = cache:set(common.GET.key,common.GET.value)
	ngx.say(result)
end
if api == "get" then
	result = cache:get(common.GET.key)
end
if api == "all" then
	local keys = cache:get_keys()
	for _, key in ipairs(keys) do
		ngx.say(key, '<br />----------<br />')
		ngx.say(cache:get(key), '<br />==========<br /><br />')
	end
end



