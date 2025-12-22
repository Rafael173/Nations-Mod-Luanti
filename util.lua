-- nations/util.lua

local M = {}

function M.split_params(s)
    local t = {}
    if not s or s == "" then return t end
    for token in string.gmatch(s, "%S+") do
        table.insert(t, token)
    end
    return t
end

function M.get_chunk_from_pos(pos)
    local cx = math.floor(pos.x / NATIONS.CHUNK_SIZE)
    local cz = math.floor(pos.z / NATIONS.CHUNK_SIZE)
    return {x = cx, z = cz}
end

function M.chunk_id(chunk)
    return tostring(chunk.x) .. "," .. tostring(chunk.z)
end

function M.name_or_id(nation)
    if not nation then return "??" end
    return ("[%d] %s"):format(nation.id, nation.name or "Unnamed")
end

return M