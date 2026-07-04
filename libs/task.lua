local uv = require("uv")
local task = {}

local frameQueue = {}
local tasksByCoroutine = setmetatable({}, { __mode = "k" })

local function ms(n) return math.floor((n or 0) * 1000) end

local function processFrame()
    local q = frameQueue
    frameQueue = {}

    for i = 1, #q do
        local tobj = q[i]
        if not tobj.cancelled then
            local co = tobj.co
            tobj.running = true
            tasksByCoroutine[co] = tobj
            local ok, err = coroutine.resume(co, table.unpack(tobj.spawnArgs or {}))
            tobj.running = false
            tasksByCoroutine[co] = nil
            if not ok then
                io.stderr:write("task error: ", tostring(err), "\n")
            end
        end
    end
end

local frameTimer = uv.new_timer()
uv.timer_start(frameTimer, 0, 16, processFrame)

-- create a task object
local function makeTaskObject(co, args)
    return {
        co = co,
        spawnArgs = args,
        cancelled = false,
        running = false,
        waitTimer = nil,     -- uv timer used by task.wait(seconds)
        delayedTimer = nil,  -- uv timer used by task.delay
    }
end

function task.spawn(fn, ...)
    assert(type(fn) == "function", "task.spawn expects a function")
    local args = { ... }
    local co = coroutine.create(fn)
    local tobj = makeTaskObject(co, args)

    local handle = {
        _task = tobj,
        cancel = function()
            if tobj.cancelled then return false end
            tobj.cancelled = true

            if tobj.waitTimer then
                pcall(uv.timer_stop, tobj.waitTimer)
                pcall(uv.close, tobj.waitTimer)
                tobj.waitTimer = nil
            end

            if tobj.delayedTimer then
                pcall(uv.timer_stop, tobj.delayedTimer)
                pcall(uv.close, tobj.delayedTimer)
                tobj.delayedTimer = nil
            end

            return true
        end,
    }

    tasksByCoroutine[co] = tobj

    table.insert(frameQueue, tobj)

    tobj.handle = handle

    return handle
end

function task.defer(fn, ...)
    assert(type(fn) == "function", "task.defer expects a function")
    local args = { ... }
    uv.next_tick(function()
        task.spawn(fn, table.unpack(args))
    end)
end

function task.delay(seconds, fn, ...)
    assert(type(seconds) == "number", "task.delay expects number")
    assert(type(fn) == "function", "task.delay expects function")

    local args = { ... }
    local handle = {}
    local timer = uv.new_timer()
    handle._timer = timer
    handle._cancelled = false

    uv.timer_start(timer, ms(seconds), 0, function()
        if handle._cancelled then
            pcall(uv.timer_stop, timer)
            pcall(uv.close, timer)
            return
        end
        task.spawn(fn, table.unpack(args))
        pcall(uv.timer_stop, timer)
        pcall(uv.close, timer)
        handle._timer = nil
    end)

    handle.cancel = function()
        if handle._cancelled then return false end
        handle._cancelled = true
        if handle._timer then
            pcall(uv.timer_stop, handle._timer)
            pcall(uv.close, handle._timer)
            handle._timer = nil
        end
        return true
    end

    return handle
end

function task.cancel(handle)
    if type(handle) ~= "table" then
        return false
    end

    if type(handle.cancel) == "function" then
        return handle.cancel()
    end

    if handle._task then
        return handle._task.handle.cancel()
    end

    return false
end

function task.wait(seconds)
    local co = coroutine.running()
    if not co then error("task.wait must be called inside a coroutine") end

    local tobj = tasksByCoroutine[co]
    if not tobj then
        if not seconds then
            local resumed = false
            table.insert(frameQueue, {
                co = co,
                spawnArgs = nil,
                cancelled = false,
                running = false,
                waitTimer = nil,
                delayedTimer = nil,
                handle = {
                    cancel = function() end
                }
            })
            return coroutine.yield()
        else
            local timer = uv.new_timer()
            uv.timer_start(timer, ms(seconds), 0, function()
                pcall(uv.timer_stop, timer)
                pcall(uv.close, timer)
                coroutine.resume(co)
            end)
            return coroutine.yield()
        end
    end

    if tobj.cancelled then
        return
    end

    if not seconds then
        table.insert(frameQueue, {
            co = co,
            spawnArgs = nil,
            cancelled = false,
            running = false,
            waitTimer = nil,
            delayedTimer = nil,
            handle = { cancel = function() end },
        })
        return coroutine.yield()
    else
        local timer = uv.new_timer()
        tobj.waitTimer = timer

        uv.timer_start(timer, ms(seconds), 0, function()
            if tobj.cancelled then
                pcall(uv.timer_stop, timer)
                pcall(uv.close, timer)
                tobj.waitTimer = nil
                return
            end

            -- Cleanup timer
            pcall(uv.timer_stop, timer)
            pcall(uv.close, timer)
            tobj.waitTimer = nil

            table.insert(frameQueue, {
                co = co,
                spawnArgs = nil,
                cancelled = false,
                running = false,
                waitTimer = nil,
                delayedTimer = nil,
                handle = { cancel = function() end },
            })
        end)

        return coroutine.yield()
    end
end

return task