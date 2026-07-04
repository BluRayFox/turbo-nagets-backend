local echo = {}

function echo.execute(args)
    print(table.concat(args, ' '))
end

return echo