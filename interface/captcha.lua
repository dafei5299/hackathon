#!/usr/bin/env lua
local print = ngx.say
local cache = ngx.shared.ngxcache
local common = require "lib.common"
local dict = require "lib.verifycode.code"
local redis = require "lib.redis.redis"
local ngxcache = ngx.shared.ngxcache
local verifycode = require "lib.verifycode.verifycode"
local verifyname = "verifycode"
local safe = require 'business.safeClass'

math.randomseed(common:getms())

local captchalevel = 1;
if captchalevel == 1 then
    length = 10
elseif captchalevel == 2 then
    length = 62
elseif captchalevel == 3 then
    length = table.getn(dict);
else
    length = 10
end

local str = {}
local code = ""
for i = 1, 4 do
    str[i] = dict[math.random(length)]
    code = code .. str[i]
end

-- 实例化redis
local redishost = ngxcache:get("redishost")
local redisport = ngxcache:get("redisport")

local redis_instance = redis:new()
local ok, err = redis_instance:connect(redishost, redisport)
if not ok then
    print("redis连接失败" .. err)
    ngx.exit(ngx.HTTP_OK)
end
local img = verifycode:getimg(str, 100, 40, 20, 5, 5, 3);
local processid = common:processid()
-- ngx.header["Content-type"] = 'text/html;charset=utf-8';
ngx.header["Content-type"] = 'image/x-png';
-- 获取用户唯一的key
local verifycode_user_key = safe:user_cookie_token("verifycode")
redis_instance:set(verifycode_user_key, code);
-- ngx.header["Set-Cookie"] = verifyname .. '=' .. processid .. '; path=/; domain=.test.com;';
print(img)