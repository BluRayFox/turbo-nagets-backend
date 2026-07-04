--[=[
   
    Usefull patches for luajit and luvit

]=]

local fs = require('fs')
local json = require('json')

local patcher = {}
local resPatches = {}

-- redirect patch
function resPatches.redirect(res)
    function res.redirect(self, path, status, finish)
        assert(path, "Redirect path required")
        self:writeHead(status or 308, {
            ["Location"] = path
        })
        if finish then self:finish() end
    end

    return
end

-- serve files just with path
function resPatches.serveFile(res)
    function res.serveFile(self, path, sync)
        if sync then
            local content, err = fs.readFileSync(path)

            if not content then
                self.statusCode = 500
                return self:finish("Error reading file: " .. tostring(err))
            end

            self:write(content)
            return self:finish()

        else
            fs.readFile(path, function(err, content)
                if err then
                    self.statusCode = 500
                    return self:finish("Error reading file: " .. tostring(err))
                end

                self:write(content)
                self:finish()
            end)
        end
    end
end

function resPatches.sendjson(res)
    function res.sendJson(self, data, status)
        self:writeHead(status or 200, {
            ["Content-Type"] = "application/json"
        })
        self:finish(json.encode(data))
    end
end

-- sender
function resPatches.send(res)
    function res.send(self, data, status)
        if type(data) == "table" then
            return self:json(data, status)
        end

        self:finish(data)
    end
end

function resPatches.status(res)
    function res.status(self, code)
        self.statusCode = code
        return self
    end
end

function patcher.patchRes(res, patchesList)
    patchesList = patchesList or {} -- make it optional
    assert(res, 'No res found.')

    for patchName, patchFunc in pairs(resPatches) do
        if patchesList[patchName] ~= false then
            patchFunc(res)
        end
    end
end

-- luajit patches
local luajitPatches = {}

luajitPatches['unpack fix'] = function()
    _G.unpack = unpack or table.unpack
    _G.table.unpack = table.unpack or unpack
end

luajitPatches['table utils'] = function()
    local function merge(target, source, seen)
        if type(target) ~= "table" or type(source) ~= "table" then
            return source
        end

        seen = seen or {}
        if seen[source] then
            return seen[source]
        end

        seen[source] = target

        for k, v in pairs(source) do
            if type(v) == "table" then
                if type(target[k]) ~= "table" then
                    target[k] = {}
                end
                merge(target[k], v, seen)
            else
                target[k] = v
            end
        end

        return target
    end

    local function deepCopy(tbl, referenceFunctions, seen)
        if type(tbl) ~= "table" then
            return tbl
        end

        seen = seen or {}

        if seen[tbl] then
            return seen[tbl]
        end

        local t = {}
        seen[tbl] = t

        for k, v in pairs(tbl) do
            local newKey = deepCopy(k, referenceFunctions, seen)

            if type(v) == "table" then
                t[newKey] = deepCopy(v, referenceFunctions, seen)
            elseif type(v) == "function" and not referenceFunctions then
                t[newKey] = nil
            else
                t[newKey] = v
            end
        end

        return setmetatable(t, getmetatable(tbl))
    end

    local function freeze(tbl, seen)
        if type(tbl) ~= "table" then return tbl end

        seen = seen or {}
        if seen[tbl] then return tbl end
        seen[tbl] = true

        for k, v in pairs(tbl) do
            freeze(v, seen)
        end

        return setmetatable(tbl, {
            __index = tbl,
            __newindex = function()
                error("Attempt to modify a frozen table", 2)
            end,
            __metatable = false
        })
    end

    local function diff(a, b, path, result)
        path = path or ""
        result = result or {}

        for k, v in pairs(a) do
            local newPath = path .. "." .. tostring(k)

            if b[k] == nil then
                result[newPath] = { removed = v }
            elseif type(v) == "table" and type(b[k]) == "table" then
                diff(v, b[k], newPath, result)
            elseif v ~= b[k] then
                result[newPath] = { from = v, to = b[k] }
            end
        end

        for k, v in pairs(b) do
            if a[k] == nil then
                local newPath = path .. "." .. tostring(k)
                result[newPath] = { added = v }
            end
        end

        return result
    end

    table.map = function(t, fn)
        local out = {}
        for k, v in pairs(t) do
            out[k] = fn(v, k)
        end
        return out
    end

    table.filter = function(t, fn)
        local out = {}
        for k, v in pairs(t) do
            if fn(v, k) then
                out[k] = v
            end
        end
        return out
    end



    table.contains = function(t, value)
        for i, v in ipairs(t) do
            if v == value then
                return i
            end
        end
        
        return false
    end

    table.find = function(t, value)
        for k, v in pairs(t) do
            if v == value then
                return k
            end
        end
        return nil
    end

    table.diff = diff
    table.freeze = freeze
    table.deepCopy = deepCopy
    table.merge = merge
end

function patcher.patchLuajit(patchesList)
    patchesList = patchesList or {} -- make it optional
    for patchName, patchFunc in pairs(luajitPatches) do
        if patchesList[patchName] ~= false then
            patchFunc()
        end
    end
end


return patcher