-- nations/database.lua
local storage = minetest.get_mod_storage()

local function ser(v) return minetest.serialize(v) end
local function des(s) 
    if not s or s == "" then return nil end
    return minetest.deserialize(s)
end

local DB = {}

function DB.load()
    DB.nations = des(storage:get_string("nations")) or {}       -- [id] = {name, id, members, points, diplomacy = {}}
    DB.chunks  = des(storage:get_string("chunks")) or {}        -- [chunkid] = {nation_id = id, private = {playername=true,...}}
    DB.players = des(storage:get_string("players")) or {}       -- [playername] = {nation_id = id, rank = 0, show_territories = true}
    DB.next_nation_id = tonumber(storage:get_string("next_nation_id")) or 0
    for id, n in pairs(DB.nations) do
    if n.capital == nil then
        n.capital = nil
    end
end
end

function DB.save()
    storage:set_string("nations", ser(DB.nations))
    storage:set_string("chunks", ser(DB.chunks))
    storage:set_string("players", ser(DB.players))
    storage:set_string("next_nation_id", tostring(DB.next_nation_id or 0))
end

-- Expose
NATIONS_DATA = DB.nations
CHUNKS_DATA  = DB.chunks
PLAYERS_DATA = DB.players

DB.load()
NATIONS_DATA = DB.nations
CHUNKS_DATA = DB.chunks
PLAYERS_DATA = DB.players

-- ensure next id initialized
DB.next_nation_id = DB.next_nation_id or 0

function DB.get_next_id()
    local id = DB.next_nation_id
    DB.next_nation_id = DB.next_nation_id + 1
    storage:set_string("next_nation_id", tostring(DB.next_nation_id))
    return id
end

function DB.commit()
    DB.save()
end

-- convenience export
db_get_next_id = DB.get_next_id
db_commit = DB.commit