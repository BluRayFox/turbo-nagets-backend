-- Finish it later

_G.MANAGER = true
_G.MANAGERVER = 'v0.1'

local server = require('./main.lua')
config.debug = true 

local json = require('json')
local fs = require('fs')

local sessionLock = false

local function checkDir(path, createOnNil)
    local ok, stat = pcall(fs.readdirSync, path)
    if not ok then
        if createOnNil then
            fs.mkdirSync(path)
            ok = true; stat = nil
        end
    end

    return ok, stat
end

local function removeDir(path)
    local ok, err = pcall(fs.rmdirSync, path)
    return ok, err
end

local function removeFile(path)
    local success, err = pcall(fs.unlinkSync, path)
    return success, err
end

local function makerDir(path)
    fs.mkdirSync(path)
end


local function exit(code)
    removeFile('./manager/session.lock')

    os.exit(code)
end

local function check()
    local success = true
    local err = ''

    checkDir('./plugins', true)

    checkDir('./manager', true)
    checkDir('./manager/scripts', true)
    checkDir('./manager/tmp', true)
    checkDir('./manager/configs', true)
    _, sessionLock = pcall(fs.readFileSync, './manager/session.lock')
    
    if sessionLock then
        print('Session is locked.')
        os.exit(0)
    else
        fs.writeFileSync('./manager/session.lock', os.time())
    end

    return success, err
end

local function parseArgs(input)
    local args = {}
    local current = ""
    local in_quotes = false
    local quote_char = nil

    local i = 1
    while i <= #input do
        local c = input:sub(i, i)

        if in_quotes then
            if c == quote_char then
                in_quotes = false
                quote_char = nil
            else
                current = current .. c
            end
        else
            if c == '"' or c == "'" then
                in_quotes = true
                quote_char = c
            elseif c:match("%s") then
                if #current > 0 then
                    table.insert(args, current)
                    current = ""
                end
            else
                current = current .. c
            end
        end

        i = i + 1
    end

    if #current > 0 then
        table.insert(args, current)
    end

    return args
end

local _, autoexec = pcall(fs.readFileSync, './manager/AUTOEXEC.lua')
if autoexec then
    loadstring(autoexec)()
end

local success, err = check()
local commands = {}
commands.neco = neco
commands.server = server

local function read(prefix)
    process.stdout:write(prefix)
    process.stdin:on('data', function(data)
        local cmd = data:gsub("[\r\n]+$", "")

        if cmd == 'exit' then
            print('Exit..')
            exit(0)
        else
            local parts = parseArgs(cmd)
            local command = table.remove(parts, 1)
            local args = parts

            for i, arg in ipairs(args) do
                arg = arg:gsub('%$([%w_]+)', function(key)
                    return _G[key] or ''
                end)
                args[i] = arg
            end
            
            dprint(getlstr('debug_manager_command_execution'):format(command, table.concat(args, ', ')))
            local module = commands[command]

            if not module then
                _, module = pcall(require, ('./manager/scripts/%s/main.lua'):format(command))
            end

            if module and module.execute then
                if not commands[command] then
                    commands[command] = module
                end

                local success, err = pcall(function()
                    module.execute(args)
                end)

                if not success then
                    print(('%s: %s'):format(command, err))
                end
            else
                print(getlstr('manager_command_not_found'):format(command))
            end

        end

        process.stdout:write(prefix)
    end)
end

read('$: ')