local handler = {}

function handler.handler(req, res)
    res:finish(req.url)
end

return handler