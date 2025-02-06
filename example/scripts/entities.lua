local entities = {}

local entries = {}

function entities.register(levelIid, entityIid, url)
    if not entries[levelIid] then
        entries[levelIid] = {}
    end
    entries[levelIid][entityIid] = url
end

function entities.get(levelIid, entityIid)
    return entries[levelIid] and entries[levelIid][entityIid]
end

return entities
