#!/usr/bin/env lua
local json = require "cjson";
local ngxcache = ngx.shared.ngxcache;
local base_dir = "/data/app/hackathon"


local limitconffile = io.open(base_dir.."/resource/limitconfig.json", "r");
local limitconf = json.decode(limitconffile:read("*all"));
limitconffile:close();
for k, v in pairs(limitconf) do  
    -- 放一个基础配置
    ngxcache:set(v.uri, json.encode(v.conf));
    -- 再放一个limit配置
    
    -- common:sort_key(table);
end 


local redisfile = io.open(base_dir.."/resource/redis.json", "r");
local redisconf = json.decode(redisfile:read("*all"));
redisfile:close();
ngxcache:set("redishost", redisconf.host);
ngxcache:set("redisport", redisconf.port);

local ipfile = io.open(base_dir.."/resource/ip.json", "r");
local ipconf = json.decode(ipfile:read("*all"));
ipfile:close();
ngxcache:set("whiteip", json.encode(ipconf.whiteip));
ngxcache:set("blackip", json.encode(ipconf.blackip));


local userfile = io.open(base_dir.."/resource/userconfig.json", "r");
local userconf = json.decode(userfile:read("*all"));
userfile:close();
ngxcache:set("usercookie", json.encode(userconf));
