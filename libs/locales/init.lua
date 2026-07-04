local mod = {}
local locales = {}

local function argerror(n, value, expected, fname)
    local got = type(value)

    if got ~= expected then
        error(("bad argument #%d to '%s' (%s expected, got %s)"):format(n, fname, expected, got), 3)
    end
end

function mod.getString(stringId, language)
    argerror(1, stringId, 'string', 'getString')
    if language then argerror(2, language, 'string', 'getString') end

    if not language then language = config.lang end
    local foundstr = (locales[language] and locales[language][stringId]) or (locales['en'] and locales['en'][stringId])

    return foundstr
end

function mod.addString(stringId, language, val)
    argerror(1, stringId, 'string', 'addString')
    argerror(2, language, 'string', 'addString')
    argerror(3, val, 'string', 'addString')
    
end

function mod.removeString(stringId, language)
    argerror(1, stringId, 'string', 'removeString')
    argerror(2, language, 'string', 'removeString')
end

function mod.addLanguage(language)
    argerror(1, language, 'string', 'addLanguage')

    if not locales[language] then
        locales[language] = {}
    else
        error(('language %s already exist'):format(language))
    end
end

function mod.removeLanguage(language)
    argerror(1, language, 'string', 'removeLanguage')

    locales[language] = {}
end

locales['en'] = require('./locales/en')
locales['ru'] = require('./locales/ru')

return mod