#!/usr/bin/env lua

local json = require 'cjson'
local print = ngx.say
local ngxcache = ngx.shared.ngxcache
local common = require 'lib.common'
local redis = require "lib.redis.redis"

local safe = require 'business.safeClass'
-- local safe = require 'business.safeClass'

-- 实例化redis
local redishost = ngxcache:get("redishost")
local redisport = ngxcache:get("redisport")

local redis_instance = redis:new()
local ok, err = redis_instance:connect(redishost, redisport)
if not ok then
    print("redis连接失败" .. err)
    ngx.exit(ngx.HTTP_OK)
end

-- 获取到uri
local uri = ngx.var.uri

-- 获取到请求的GET、POST参数
local args = common:merge_args()



-- debug
local debug = false;
if args.debug then
    debug = true;
end

-- dubug talbe
local debug_table = {}

local useragent = safe:httpagent();
if useragent then
    ngx.say("禁止使用curl获取资源")
    ngx.exit(ngx.HTTP_OK)
end


--1、内网ip + 全局ip黑名单
local ip_black_limit_result = safe:ip_black_limit()
if ip_black_limit_result.status == true and args["debug"] == nil then
    ngx.say(ip_black_limit_result.info)
    ngx.exit(ngx.HTTP_OK)
end
if args["debug"] == "true" then
    debug_table.ip_black_limit_result_info = ip_black_limit_result.info
    if ip_black_limit_result.status == true then
        common:print_debug_log(debug_table)
    end
end

-- 2、ip白名单
local ip_white_limit_result = safe:ip_white_limit()
if ip_white_limit_result == false then
    -- 没有触发ip白名单，则执行后面的限制逻辑

    -- 3、请求uri或参数限制
    local limit_conf = safe:uri_limit_conf(uri, args)

    if next(limit_conf) ~= nil then
        -- limit_conf不为空，证明有限制存在

        if limit_conf.type == "IPLIMIT" then
            local uri_ip_limit = safe:uri_ip_limit(limit_conf, redis_instance)
            if uri_ip_limit.status == true and args["debug"] == nil then
                ngx.say(uri_ip_limit.remote_addr .. "您单位时间内请求的次数已经超过限制")
                ngx.exit(ngx.HTTP_OK)
            end
            if args["debug"] == "true" then
                debug_table.uri_ip_limit_info = uri_ip_limit.info
                if uri_ip_limit.status == true then
                    common:print_debug_log(debug_table)
                end
            end
        elseif limit_conf.type == "VERIFYCODE" then
            -- 生成usercookie
            local uri_ip_limit, key = safe:uri_verifycode_limit(limit_conf, redis_instance);
            if uri_ip_limit.status == true then
                local returnurl = "http://" .. ngx.var.host .. ngx.var.uri
                -- for k, v in pairs(args) do
                --     returnurl = returnurl .. k .. "=" .. v .. "&"
                -- end
                ngx.redirect("http://" .. ngx.var.host .. "/verifycode.html?key=" .. key .. "&returnurl=" .. returnurl, 302)
            end
        elseif  limit_conf.type == "ACCESSTOKEN" then
            local uri_token_limit = safe:uri_token_limit(limit_conf,redis_instance)
            if uri_token_limit.status == true and args["debug"] == nil then
                ngx.say(uri_token_limit.remote_token .. "非法请求,Token未授权")
                ngx.exit(ngx.HTTP_OK)
            end
            if args["debug"] == "true" then
                debug_table.uri_token_limit_info = uri_token_limit.info
                if uri_token_limit.status == true then
                    common:print_debug_log(debug_table)
                end
            end
        else -- TIMESLIMIT
            local uri_times_limit = safe:uri_times_limit(limit_conf, redis_instance)
            if uri_times_limit.status == true and args["debug"] == nil then
                ngx.say("您单位时间内请求的次数已经超过限制")
                ngx.exit(ngx.HTTP_OK)
            end
            if args["debug"] == "true" then
                debug_table.uri_times_limit_info = uri_times_limit.info
                if uri_times_limit.status == true then
                    common:print_debug_log(debug_table)
                end
            end
        end 
    end
end



-- local function close_redis(redis_instance)  
--     if not redis_instance then  
--         return  
--     end  
--     --释放连接(连接池实现)  
--     local pool_max_idle_time = 10000 --毫秒  
--     local pool_size = 100 --连接池大小  
--     local ok, err = redis_instance:set_keepalive(pool_max_idle_time, pool_size)  
  
--     if not ok then  
--         ngx_log(ngx_ERR, "set redis keepalive error : ", err)  
--     end  
-- end 


-- ngx.redirect(dest,302)

-- close_redis(redis_instance)


-- 2、用户请求限制

-- 3、

-- for k, v in pairs(limit_result) do
--     ngx.say(k .. "=" .. v .. "<br>")
-- end



-- for k,v in pairs(args) do  
    -- if type(v) == "table" then  
    --     ngx.say(k, " : ", table.concat(v, ","), "<br/>")  
    -- else  
        -- ngx.say(k .. "=" .. v .. "<br>")  
    -- end  
-- end 

-- ngx.exit(ngx.HTTP_OK)
