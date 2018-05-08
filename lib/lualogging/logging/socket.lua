-------------------------------------------------------------------------------
-- Sends the logging information through a socket using luasocket
--
-- @author Thiago Costa Ponte (thiago@ideais.com.br)
--
-- @copyright 2004-2013 Kepler Project
--
-------------------------------------------------------------------------------

-- local logging = require"logging"
local logging = dofile(ngx.var.base_path .. "/libs/lualogging/logging.lua")
local socket = require"socket"

function logging.socket(address, port, logPattern)
	return logging.new( function(self, level, message)
		local s = logging.prepareLogMsg(logPattern, os.date(), level, message)

		local socket, err = socket.connect(address, port)
		if not socket then
			return nil, err
		end

		local cond, err = socket:send(s)
		if not cond then
			return nil, err
		end
		socket:close()

		return true
	end)
end

return logging.socket

