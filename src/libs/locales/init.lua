local mod = {}
local locales = {}

local function argerror(n, value, expected, fname)
    local got = type(value)

    if got ~= expected then
        error(("bad argument #%d to '%s' (%s expected, got %s)"):format(n, fname, expected, got), 3)
    end
end

function mod.getString(stringId, language)
    
end

function mod.addString(stringId, language)
    
end

function mod.removeString(stringId, language)
    
end

function mod.addLanguage(language)
    argerror(1, language, 'string', 'addLanguage')

    if not locales[language] then
        locales[language] = {}
    else
        error(('language %s is already exist'):format(language))
    end
end

function mod.removeLanguage(language)
    
end

return mod