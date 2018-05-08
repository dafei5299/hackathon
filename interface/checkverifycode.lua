#!/usr/bin/env lua
local safe = require 'business.safeClass'
local redis = require "lib.redis.redis"
local ngxcache = ngx.shared.ngxcache
local common = require 'lib.common'

-- 实例化redis
local redishost = ngxcache:get("redishost")
local redisport = ngxcache:get("redisport")

local common = require 'lib.common'

local redis_instance = redis:new()
local ok, err = redis_instance:connect(redishost, redisport)
if not ok then
    print("redis连接失败" .. err)
    ngx.exit(ngx.HTTP_OK)
end
-- $verifycode_text
local verifycode_user_key = safe:user_cookie_token("verifycode")
local redis_code = redis_instance:get(verifycode_user_key)

local args = common:merge_args()

local img_code = args.verifycode_text
-- ngx.say(redis_code);
-- ngx.log(img_code .. redis_code);
-- ngx.exit(200);

if tostring(redis_code) == tostring(img_code) then

    safe:uri_verifycode_dellimit(args.key, redis_instance) 
    ngx.redirect(args.returnurl)
else
    -- local verifycode_times_key = verifycode_user_key .. "_times"
    -- local exists = redis_instance:exists(verifycode_times_key)
    -- local times = 0;
    -- if exists ~= 0 then
    --     times = tonumber(redis_instance:get(verifycode_times_key))
    --     redis_instance:incr(verifycode_times_key)
    -- else
    --     times = 1;
    --     redis_instance:set(verifycode_times_key,times)
    --     redis_instance:expire(verifycode_times_key, 60)
    -- end
end
ngx.redirect("http://" .. ngx.var.host .. "/verifycode.html?returnurl=" .. args.returnurl, 302)

ngx.say(redis_code)
