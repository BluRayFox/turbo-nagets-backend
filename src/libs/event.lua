local event = {}

local function connection(e, f)
    local c = {}
    c.active = true
    c.f = f
    c.event = e
    c.id = e.__nextConnectionId + 1

    e.connections[c.id] = c
    e.__nextConnectionId =  e.__nextConnectionId + 1

    function c:disconnect()
        self.active = false
        c.f = nil
        e.connections[c.id] = nil
    end

   --  print('connected with id', c.id)

    return c
end

function event.new()
    local self = {}; setmetatable(self, {__index = event})

    self.connections = {}
    self.__nextConnectionId = 0

    return self
end

function event:fire(...)
    for i, connection in pairs(self.connections) do
        local f = connection.f
        if f and connection.active then
            local success, err = pcall(f, ...)

            if not success then
                print('unable to process the connection: '..err)
            end

        end
    end
end


function event:connect(f)
    local conn = connection(self, f)
    return conn
end


return event