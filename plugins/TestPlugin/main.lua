local plugin = {}

plugin.init = function()
    print('Plugin Loaded!')
end

function plugin.test()
    print('test')
end

return plugin