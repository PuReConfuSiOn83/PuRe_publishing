PurePub = PurePub or {}

PurePub.Types = {
    newspaper = 'Zeitung',
    menu = 'Speisekarte',
    wanted = 'Fahndung'
}

function PurePub.ValidType(value)
    return type(value) == 'string' and PurePub.Types[value] ~= nil
end

function PurePub.Trim(value)
    if type(value) ~= 'string' then return '' end
    return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

function PurePub.SafeImageUrl(value)
    if value == nil or value == '' then return '' end
    if type(value) ~= 'string' or #value > Config.MaxImageUrlLength then return nil end
    if not value:match('^https://[%w%.%-]+/') and not value:match('^https://[%w%.%-]+$') then return nil end
    return value
end
