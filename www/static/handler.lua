local qs = require('querystring')
local url = require('url')
local fs = require('fs')

local handler = {}

function handler.handler(req, res)
    
    local parsed = url.parse(req.url)
    local queryParsed = parsed.query and qs.parse(parsed.query)

    local filename = queryParsed and queryParsed.fn or nil
    if not filename then
        res:redirect('/not-found', nil, true) 
        return
    end

     fs.readFile('./www/static/files/'..filename, function(err, data)
        print('Static file requested: ' .. './www/static/files/'..filename)
        if err then
            print('error opening file: '..err)
            res:redirect('/not-found', nil, true)
            return
        end

        res:finish(data)
    end)

end

return handler