-- Datastore
-- TODO: allow Connect to mongo db or similar db and use those instead of local json files

local ds = {}
local fs = require 'fs'
local json = require 'json'
local path = require 'path'

function ds.new(name, path)
    local self = {}; setmetatable(self, {__index = ds})

    self.name = name or 'datastorage'
    self.path = path or 'storage/ds/'
    self.lastSaved = 0
    self.lastLoaded = 0
    -- self.version = 1
    self.data = {}

    return self
end

function ds:save()
    local save = {}
    save['VERSION'] = _G.VERSION
    save['DATA'] = self.data

    local data = json.encode(save)
    fs.writeFile(path.join(self.path, self.name .. '.ds'), data)
end

function ds:load()
    fs.readFile(path.join(self.path, self.name .. '.ds'), function(err, data)
        if err then
            print('unable to load datastore: '..err)
        elseif data then
            print('Data to load: ', data)
            local raw = json.decode(data)
            if raw and raw.DATA then
                self.data = raw.DATA
            end
        end
    end)
end

function ds:get(k)
    k = k and tostring(k)
    local raw = self.data[k]

    if not raw then return raw end

    if raw.type == 'table' then
        return json.decode(raw.value), _
    else
        return raw.value
    end
end

function ds:set(k, v)
    if type(v) == 'number' or type(v) == 'string' then
        self.data[k] = {type = type(v), value = v}
    elseif type(v) == 'table' then
        self.data[k] = {type = type(v), value = json.encode(v)}
    else
        error('unsupported value type', 2)
    end    
end

return ds