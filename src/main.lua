
-- packages and libs require aliases
-- elite ball knowledge
package.path = './libs/?.lua;'
    .. './libs/?/init.lua;'
    .. package.path

local http = require('http')
------
local config = require('./config')
local patcher = require('patcher')
local utils = require('utils')
local task = require('task')
------

-- globals --
_G.utils = utils
_G.patcher = patcher
_G.task = task

_G.ipReqPerSec = {}
_G.rateLimitedIps = {}

http.createServer(function(req, res)
    -- patch res 
    patcher.patchRes(res, {redirect = true})
    
    local urlTable = utils.urlToTable(req.url)
    local address = req.socket:address().ip

    task.spawn(function()
        ipReqPerSec[address] = (ipReqPerSec[address] or 0) + 1

        if ipReqPerSec[address] >= config.rateLimit and not rateLimitedIps[address] then
            rateLimitedIps[address] = true
            
            task.delay(15, function()
                rateLimitedIps[address] = nil  -- memory efficent!!
            end)
        end

        task.wait(1)
        ipReqPerSec[address] = (ipReqPerSec[address] or 0) - 1

        if ipReqPerSec[address] <= 0 then
            ipReqPerSec[address] = nil -- memory efficent!!
        end
    end)

    if rateLimitedIps[address] then
        res.statusCode = 429
        res:finish('429: Too Many Requests.')
        return
    end

    local www = ''

    if req.url == '/' then 
        www = '.home'

    else
        www = req.url:sub(2, #req.url)

    end

    local logMessage = '[%s|%s]: %s -> %s' -- time, ip, method, path
    print(logMessage:format(os.date('%H:%M:%S'), address, req.method, req.url))
    
    local success, handler = pcall(function()
        return require('./www/'..www..'/handler')
    end)
    
    if not success then
        success, handler = pcall(function()
            return require('./www/'..urlTable[1]..'/handler')
        end)
    end

    if not success then
        res:redirect('/not-found', nil, true)
        return
    end

    local success, err = pcall(function()
        handler.handler(req, res)
    end)

    if not success then
        res:finish('503: Unable to complete the request.')
        print('Unable to complete the request: '..err)
    end

    return
end):listen(config.port)

print('Running on http://localhost' .. (config.port ~= 80 and ':'..config.port or ''))