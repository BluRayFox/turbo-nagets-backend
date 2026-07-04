local handler = {}
local fs = require('fs')

function handler.handler(req, res)
    local iconFile = './www/favicon.ico/icon'
   
    fs.readFile(iconFile, function(err, data)
        if err then
            res.statusCode = 404
            return res:finish('Not Found.')
        end

        res:setHeader("Content-Type", "image/x-icon")
        res:finish(data)
    end)
end

return handler