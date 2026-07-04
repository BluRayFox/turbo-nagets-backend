local set = {}

function set.execute(args)
    local var = args[1]
    args[3] = args[3] or ''
    local val

    -- Case 1
    if args[2] == '=' then
        val = args[3] or ''

    -- Case 2
    elseif var and var:find('=') then
        local name, value = var:match("^([^=]+)=(.*)$")
        var = name
        val = value
    end

    _G[var] = val
end

return set