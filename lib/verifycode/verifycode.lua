#!/usr/bin/env lua

gd = require "gd"
-- require "lfs"


local font = ngx.var.base_path .. "/lib/verifycode/simhei.ttf"

local captcha = {};
function captcha:getimg(str,width,height,fontsize,linenum,pointnum,rectanglenum)
	if width == nil then
		width = 100
	end
	if width == nil then
		height = 40
	end
	if fontsize == nil then
		fontsize = 14  -- fontsize必须为偶数
	end
	if linenum == nil then
		linenum = 0
	end
	if pointnum == nil then
		pointnum = 0
	end
	if rectanglenum == nil then
		rectanglenum = 0
	end
	-- font = ngx.var.base_path .. "/simhei.ttf"
	
	im = gd.create(width, height)
	white = im:colorAllocate(255, 255, 255)
	black = im:colorAllocate(0, 0, 0)
	
	-- 画验证码
	for key, val in pairs(str) do
		x = width * (key - 1) / 4 + math.random(width / 16)
		y = height - math.random(0,height - fontsize)
		im:stringFT(black, font, fontsize, math.rad(math.random(-30,30)), x, y, val)
	end
	-- 画干扰线
	for i = 1 ,linenum do
		randomcolor = im:colorAllocate(math.random(0,255), math.random(0,255), math.random(0,255))
		im:line(math.random(width),math.random(height),math.random(width),math.random(height),randomcolor)
	end
	-- 画噪点
	for i = 1, pointnum do
		randomcolor = im:colorAllocate(math.random(0,255), math.random(0,255), math.random(0,255))
		-- im:setPixel(math.random(width),math.random(height),randomcolor)
		im:string(gd.FONT_TINY,math.random(width),math.random(height), "*", randomcolor)
	end
	-- 随机矩形
	for i = 1, rectanglenum do
		randomcolor = im:colorAllocate(math.random(0,255), math.random(0,255), math.random(0,255))
		im:rectangle(math.random(width),math.random(height), math.random(width),math.random(height), randomcolor)
	end
	
	return im:pngStr()
end

return captcha,font

