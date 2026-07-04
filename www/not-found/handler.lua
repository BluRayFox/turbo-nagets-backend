local handler = {}
local fs = require('fs')

function handler.handler(req, res)
    local indexFile = './www/not-found/index.html'
   
    fs.readFile(indexFile, function(err, data)
        if err then
            res.statusCode = 503
            return res:finish()
        end

        res.statusCode = 404
        res:finish(data)
    end)
end

return handler