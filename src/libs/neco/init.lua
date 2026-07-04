-- Neco Plugin Manager 

local neco = {}
neco.loadedPlugins = {}

local nconfig = require('./config') -- Manager configuration
local fs = require('fs')
local path = require('path')

local pluginsPath = path.join(require('uv').cwd(), 'plugins')

neco.events = {} -- New event system

local function getMeta(name)
    local full = path.join(pluginsPath, name)
    local stat = fs.statSync(full)
    
    local str = ' %s %s'
    
    local meta
    local metaLua, metaLuaError = fs.readFileSync(path.join(full, 'meta.lua'))

    if metaLua then
        local env = {}
        local getMeta = loadstring(metaLua)
        if not getMeta then return end

        setfenv(getMeta, env)
        local success, metaData = pcall(getMeta)
        meta = metaData
    end

    return meta or {}
end

function neco.loadPlugins()
    error('not supported', 2)

    for _, name in ipairs(fs.readdirSync(pluginsPath)) do
        local full = path.join(pluginsPath, name)
        local stat = fs.statSync(full)

        if not stat.type == 'directory' then
            goto continue
        end

        local mainLua, metaLua, mainLuaError, metaLuaError, meta, plugin
        mainLua, mainLuaError = fs.readFileSync(path.join(full, 'main.lua'))
        metaLua, metaLuaError = fs.readFileSync(path.join(full, 'meta.lua'))


        local success, err = pcall(function()

            local metaCompiled = loadstring(metaLua)
            local main = loadstring(mainLua)

            if metaCompiled then
                setfenv(metaCompiled, {}) -- safe
                meta = metaCompiled()
            else
                error(getlstr('plugin_load_faliure_does_not_exist'):format('meta.lua'))
            end

            print(getlstr('plugin_loading_plugin'):format(meta.name or 'Unknown Plugin'))

            if meta.requires.backend_version ~= VERSION then
                if nconfig.allowIncompatiblePlugins then
                print(getlstr('plugin_allow_incompatble_version')) 
                else
                    error(getlstr('plugin_incompatble_version')) 
                end
            end

            if main then
                plugin = main()
                if plugin and plugin.init then plugin.init() end
            else
                error(getlstr('lugin_load_faliure_does_not_exist'):format('main.lua'))
            end
        end)

        if success then
            neco.loadedPlugins[meta.name or 'Unknown Plugin'] = plugin
        else
            print(err)
        end

        -- Expose plugin apis
        _G[meta.name] = plugin
        ::continue::
    end
end

local function newplugin(metaSrc, mainSrc)
    local plugin = {}

    local meta = loadstring(metaSrc)
    local main = loadstring(mainSrc)

    if meta then
        setfenv(meta, {})
    end

    plugin.meta = meta and meta() or {}
    plugin.main = main

    return plugin
end

-- Rewritten load logic
-- TODO: 
-- Includes dynamic execution reordering based on 
-- required table in meta
function neco.loadPluginsV2()
    
    local toLoad = {}  -- Ordered

    for i, name in pairs(fs.readdirSync(pluginsPath)) do
        local full = path.join(pluginsPath, name)
        local stat = fs.statSync(full)

        if stat.type ~= 'directory' then goto continue end
       
        local meta = fs.readFileSync(path.join(full, 'meta.lua'))
        local main = fs.readFileSync(path.join(full, 'main.lua'))

        if not main then
            error('Plugin does not contain main.lua', 2)
        end

        local plugin = newplugin(meta, main)
        toLoad[plugin.meta.name or ('Unknown Plugin '..os.clock())] = plugin

       
        ::continue::
    end

    for pluginName, plugin in pairs(toLoad) do
        
        local requires = plugin.meta.requires 
        local backend = plugin.meta.backend

        if backend ~= _G.VERSION then
            if nconfig.allowIncompatiblePlugins then
                print(getlstr('plugin_allow_incompatble_version'))
            else
                error(getlstr('plugin_incompatble_version'))
                goto continue
            end


        end

        print('Loading plugin: '..plugin.meta.name)
        
        local success, err = pcall(function()
        
        local pplugin = plugin.main()
        plugin.plugin = pplugin
        pplugin.init()
        
        neco.loadedPlugins[plugin.meta.name] = plugin

        end)
        
        ::continue::
    end

end

function neco.list()
    print('List of installed plugins:')
    for _, name in ipairs(fs.readdirSync(pluginsPath)) do
        local full = path.join(pluginsPath, name)
        local stat = fs.statSync(full)
        
        local str = ' %s %s'
        
        local success, meta = pcall(getMeta, name)
        if not success then
            goto continue
        end
        
        str = str:format(meta.name or 'Unknown', ('ver. ' .. meta.version) or 'Unknown')
        
        print(' ' .. str)


        ::continue::
    end
end

function neco.execute(args)
    if args[1] == 'list' then
        neco.list()
    end
end

-- TODO: Replace the event function or remove it
function neco.event(event, ...)
    print'WARNING: using deprecated function neco.event. Consider using neco.events table!'    
    for pluginName, module in pairs(neco.loadedPlugins) do
        if module[event] then
            local success, err = pcall(module[event], ...)
            if not success then
                print(('%s: %s'):format(pluginName, err))
            end
        end
    end
end

-- Create events
neco.events['onServerRequest'] = event.new()
neco.events['onServerRequestWritable'] = event.new()


return neco