
_G.VERSION = 'v0.1.4-alpha'

-- packages and libs require aliases
package.path = './libs/?.lua;'
    .. './libs/?/init.lua;'
    .. package.path

local http = require('http')
local url = require('url')
local patcher = require('patcher')
patcher.patchLuajit() -- for some reason crashes on termux if 
                      -- certain patches are not applied
------      ------
_G.ocular = require('ocular')
_G.event = require('event')     -- Event system.
_G.config = require('./config')
_G.locales = require('locales')
_G.getlstr = locales.getString
_G.utils = require('utils')
_G.task = require('task')
_G.neco = require('neco')
_G.ds = require('ds')
_G.datastores = {}  -- Global Datastore Table Collection

------      ------

-- globals --
_G.patcher = patcher
_G.ipReqPerSec = {}
_G.rateLimitedIps = {}
_G.errorlogs = {}

-- Functions
local dprint = utils.dprint
_G.dprint = dprint
_G.getlstr = locales.getString

-- Manager Integration
local server = {}
server.execute = function(args)

    if args[1] == 'mainserver' then
        if args[2] == 'start' then
            server.startMainserver()
        elseif args[2] == 'stop' then
            server.stopMainserver()
        end
    end
    
end

server.startMainserver = function()

neco.loadPluginsV2()

_G.mainserver = http.createServer(function(req, res)
    -- patch res 
    patcher.patchRes(res, {redirect = true})
    
    local urlTable = utils.urlToTable(req.url)
    local address = req.socket:address().ip


    -- Check rate limit first.
    -- Do not process the request if rate limited!
    if rateLimitedIps[address] then
        res.statusCode = 429
        res:finish('429: Too Many Requests.')
        return
    end

    do -- TODO: Add neco events to use event module [Partially done]
        local scReq = table.deepCopy(req, false)
        local scRes = table.deepCopy(res, false)

        -- neco.event('onServerRequest', scReq, scRes)
        neco.events['onServerRequest']:fire(scReq, scRes)

        -- neco.event('onServerRequestWritable', req, res)
        neco.events['onServerRequestWritable']:fire(req, res)

    end

    -- Rate Limit Tasks --
    task.spawn(function()
        ipReqPerSec[address] = (ipReqPerSec[address] or 0) + 1

        if ipReqPerSec[address] >= config.rateLimit and not rateLimitedIps[address] then
            rateLimitedIps[address] = true
            
            task.delay(config.rateLimitTimer, function()
                rateLimitedIps[address] = nil  -- memory efficent!!
            end)
        end

        task.wait(1)
        ipReqPerSec[address] = (ipReqPerSec[address] or 0) - 1

        if ipReqPerSec[address] <= 0 then
            ipReqPerSec[address] = nil -- memory efficent!
        end
    end)

    -- Logging
    local logMessage = '[%s||%s]: %s -> %s' -- time, ip, method, path
    print(logMessage:format(os.date('%H:%M:%S'), address, req.method, req.url))

    -- Routing part 
    local parsed = url.parse(req.url)
    local path = parsed.pathname

    local www
    if path == '/' then
        www = '.home'
    else
        www = path:sub(2)
    end

    -- ROUTER --
    local handler
    local success = false

    local segments = utils.urlToTable(path)

    if path == "/" then
        success, handler = pcall(function()
            return require('./www/.home/handler')
        end)
    else
        for i = #segments, 1, -1 do
            local route = table.concat(segments, "/", 1, i)

            success, handler = pcall(function()
                return require('./www/' .. route .. '/handler')
            end)

            if success then
                www = route
                break
            end
        end
    end

    if not handler then
        res:redirect('/not-found', nil, true)
        return
    end

    local success, err = pcall(function()
        
        local env = {}  -- Build environment for handler
        setmetatable(env, {__index = _G})

        env.print = function(...)
            local msg = '   [%s||%s]: ' .. table.concat({...}, '   ')

            print(msg:format(www, 'handler'))
        end
        
        if not handler or not handler.handler then
            error('no handler found')
        end

        setfenv(handler.handler, env)
        handler.handler(req, res)
    end)

    if not success then
        res:finish('503: Unable to complete the request.')
        print(getlstr('503'):format(err))
    end

    return
end)
mainserver:listen(config.port or 80)
server.mainserver = mainserver

print(getlstr('running_on_host'):format('http://localhost' .. (config.port ~= 80 and ':'..config.port or ':80')))

end

server.stopMainserver = function ()
    print('Stopping the server...')
    server.mainserver:destroy()
end

-- Code
if _G.MANAGER then return server end
dprint(getlstr('debug_mode_enabled'))

server.startMainserver()