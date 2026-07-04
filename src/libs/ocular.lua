local ocular = {}

-- Argument type check
local function argcheck(v, e, p, n)
    if type(v) ~= e then
        error(("bad argument #%s to '%s' (%s expected, got %s"):format(p, n, e, type(v)), 3)
    end
end

-- Convert table into a human readable string
function ocular.look(t, n, d)
    local start = os.clock()

    local n = n or 1
    local d = d or 10
    local first = true
    local str = '{'

    argcheck(t, 'table', 1, 'look')
    argcheck(n, 'number', 2, 'look')
    argcheck(d, 'number', 3, 'look')


    for k, v in pairs(t) do
        if not first then
            str = str .. ','
        end

        str = str .. '\n'

        for i=1, n do
            str = str .. '  '
        end

        str = str .. (type(k) == 'string' and '"' .. k .. '"' or k) .. ' = '
        
        if type(v) == 'table' then
            
            if n == d + 1 then
                str = str .. '{...}'
            else
                 str = str .. ocular.look(v, n + 1, d)
            end
            
           
        elseif type(v) == 'string' then
            str = str .. '"' .. v .. '"'
        else
            str = str .. tostring(v)
        end

        first = false
    end

    str = str .. '\n'

   if n-1 > 0 then
        for i=1, n -1 do
            str = str .. '  '
        end
   end

    str = str .. '}'


    return str, os.clock() - start
end

return ocular