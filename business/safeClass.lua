#!/usr/bin/env lua

local ipcache = "ipoutbreak"
local json = require 'cjson'
local ngxcache = ngx.shared.ngxcache
local common = require 'lib.common'
local cookie = require 'lib.cookie.cookie'

local safe = {}


function safe:httpagent() 
    local httpuseragent = ngx.var.http_user_agent;
    if not string.match(httpuseragent,'curl')  then
        return false
    else
        return true
    end
end

-- ip黑名单 return true为触发黑名单
function safe:ip_black_limit()
    local remote_addr = common:requestIP()
    local blackip_str = ngxcache:get("blackip")
    local blackip = json.decode(blackip_str)
    local result = {}
    for _, v in pairs(blackip) do
        local m, err = ngx.re.match(remote_addr, v)
        if m then
            -- 触发黑名单，直接禁止
            result.status = true
            result.info = "ip_black_limit:"..remote_addr .. "禁止访问该资源<br>"
            return result
        end
    end
    result.status = false
    result.info = "ip_black_limit:"..remote_addr .. "允许访问该资源————通过<br>"
    return result
end

-- ip白名单
function safe:ip_white_limit()
    local remote_addr = common:requestIP() 
    local whiteip_str = ngxcache:get("whiteip")
    local whiteip = json.decode(whiteip_str)
    for _, v in pairs(whiteip) do
        local m, err = ngx.re.match(remote_addr, v)
        if m then
            return true
        end
    end
    return false
end

-- 获取配置
function safe:uri_limit_conf(uri, args) 
    -- 把所有的GET、POST参数拼接放在table里
    local args_table = {}
    for k, v in pairs(args) do
        table.insert(args_table, k .. "=" .. v)
    end
    local limit_result = {}
    -- 获取到请求的配置
    local limit_conf_str = ngxcache:get(uri)
    if limit_conf_str ~= nil then
        local limit_conf = json.decode(limit_conf_str)
        for k, v in pairs(limit_conf) do
            local is_exist = nil
            -- 如果有参数的url限制
            if v.filter ~= nil then
                for _, v in pairs(v.filter) do
                    if is_exist == false then break end
                    if common:is_include(args_table, v) then
                        is_exist = true
                    else
                        is_exist = false
                    end 
                end
            else
            -- 只对uri进行限制
                is_exist = true
            end
            if is_exist == true then
                if v.filter ~= nil then
                    local param_v_tab = v.filter
                    -- 这里对param进行排序，这样后面md5的值可以不会被param的顺序影响
                    table.sort(param_v_tab)
                    limit_result.param = json.encode(param_v_tab)
                end
                limit_result.type = v.type
                limit_result.times = v.times
                limit_result.section = v.section
                limit_result.uri = uri
                break
            end
        end
    end
    return limit_result
end

-- 次数限制
function safe:uri_times_limit(conf, rediscache) 
    -- conf md5
    local key = ngx.md5(json.encode(conf))
    local result = limit(key, conf, rediscache);
    if result.status then
        result.info = "uri_times_limit " .. "您单位时间内请求的次数:" .. result.req_times .. " 已经超过限制:" .. result.conf_times.."<br>"
        return result;
    end
    result.info = "uri_times_limit " .. "您单位时间内请求的次数:" .. result.req_times .. " 未超过限制：" .. result.conf_times.."————通过<br>"
    return result;
end

-- 验证码限制
function safe:uri_verifycode_limit(conf, rediscache) 
    -- conf md5
    local remote_addr = common:requestIP()
    -- 接口conf json + ip作为唯一key
    local key = ngx.md5(json.encode(conf) .. remote_addr)

    -- 请求3次，则直接拒绝
    -- local exists = rediscache:exists(key .. "_times")
    -- local times = 0;
    -- if exists ~= 0 then
    --     times = tonumber(rediscache:get(key .. "_times"))
    -- end
    -- ngx.say(times);
    -- if times > 3 then
    --     ngx.exit("您的验证码输入次数过多");
    -- end
    local result = limit(key, conf, rediscache);
    if result.status then
        result.info = "uri_verifycode_limit " .. "您单位时间内请求的次数:"..result.req_times .." 限制次数:"..result.conf_times.."<br>"
        return result, key;
    end
    result.info = "uri_verifycode_limit " .. "您单位时间内请求的次数:"..result.req_times .." 限制次数："..result.conf_times.."————通过<br>"
    return result, key;
end

function safe:uri_verifycode_dellimit(key, rediscache) 
    rediscache:del(key);
end

-- TOKEN Limit
function safe:uri_token_limit(conf, rediscache)
    -- conf md5
    local remote_token = safe:user_cookie_token("TOKEN")
    -- 接口conf json + token作为唯一key

    local key = ngx.md5(json.encode(conf) .. remote_token)
    local result = limit(key, conf, rediscache);
    result.remote_token = remote_token
    if result.status then
        result.info = "uri_token_limit:" .. "非法请求,Token:"..remote_token .. "未授权<br>"
        return result
    end
    result.info = "uri_token_limit:" .. "合法请求,Token:"..remote_token .. "已授权————通过<br>"
    return result;
end

function safe:uri_ip_limit(conf, rediscache)
    local remote_addr = common:requestIP()
    local cookie_conf = json.decode(ngxcache:get("usercookie"))
    local user_agent = "";
    if cookie_conf.switch == true then
        local cookie, err = cookie:new()
        user_agent = user_cookie_key(cookie, cookie_conf) 
    end
    -- 接口conf json + ip作为唯一key
    local key = ngx.md5(json.encode(conf) .. remote_addr .. user_agent)
    -- ngx.say(json.encode(conf) .. remote_addr .. user_agent);
    local result = limit(key, conf, rediscache);
    result.remote_addr = remote_addr
    if result.status then
        result.info = "uri_ip_limit:" .. remote_addr .. "您单位时间内请求的次数:"..result.req_times .."已经超过限制:"..result.conf_times.."<br>"
        return result;
    end
    result.info = "uri_ip_limit:" .. remote_addr .. "您单位时间内请求的次数:"..result.req_times .."未超过限制："..result.conf_times.."————通过<br>"
    return result;
end

function limit(key, conf, rediscache)
    -- 生成唯一请求id，防止redis的member重复导致覆盖
    conf.guid = common:processid()
    -- 1、先加入到请求队列中
    rediscache:zadd(key, ngx.now() * 1000, json.encode(conf))
    local section = tonumber(conf.section) * 60 -- 单位：秒
    rediscache:expire(key, section)
    local result_talbe = {}
    -- 2、获取限制次数
    local starttime = ngx.now() * 1000 - section * 1000
    local endtime = ngx.now() * 1000
    local result = rediscache:zrevrangebyscore(key, 0, starttime) -- 超过时间间隔的都会被删掉
    local req_times, err = rediscache:zcount(key, starttime, endtime) -- 获取当前时间-时间间隔 到当前时间内的请求次数

    result_talbe.req_times = req_times
    result_talbe.conf_times = conf.times
    if req_times > tonumber(conf.times) then
        result_talbe.status = true
        return result_talbe
    end
    result_talbe.status = false
    return result_talbe
end


function safe:user_cookie_token(typename)
    local cookie_conf = json.decode(ngxcache:get("usercookie"))
    local cookie, err = cookie:new()
    local user_agent = user_cookie_key(cookie, cookie_conf) 
    -- 向用户端，种植一个带有业务性质的cookie
    local cookie_name = cookie_conf.selfcookiename .. "_" .. typename
    local cookie_value = ngx.md5(user_agent)
    local field ,err = cookie:set({
        key = cookie_name, 
        value = cookie_value, 
        path = "/",
        domain = cookie_conf.domain,
        expires = os.date("%a, %d %b %Y %X GMT", os.time() + cookie_conf.expires)
    })
    return cookie_value
end

function user_cookie_key(cookie, cookie_conf) 
    local user_identity = common:user_identity()
    -- 如果是自行解决用户认证，则自己种cookie
    local user_agent = ""
    if cookie_conf.type == "SELF" then
        -- 通过浏览器+ip来限制用户
        user_agent = user_identity
    elseif cookie_conf.type == "SERVICE" then
        -- 如果是通过业务的cookie解决用户认证，for循环获取业务的cookie
        local user_cookie = {}
        for _, v in pairs(cookie_conf.usercookie) do
            user_cookie[v] = cookie:get(v)
        end
        table.sort(user_cookie)
        for k, v in pairs(user_cookie) do
            user_agent = user_agent .. k .. "=" .. v
        end
        user_agent = user_identity .. user_agent
    end
    return user_agent
end

-- 有可能是verifycode或者accesstoken
function safe:get_user_cookie_token(typename)
    local cookie, err = cookie:new()
    local cookie_name = cookie_conf.selfcookiename .. "_" .. typename
    local user_agent_cookie = cookie:get(cookie_name)
    if not fields then
        return nil
    else
        return user_agent_cookie
    end
end

return safe


