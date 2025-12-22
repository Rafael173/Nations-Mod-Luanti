-- nations/hud.lua

local util = dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/util.lua")

local huds = {}
local timers = {}
local update_timer = 0
local update_interval = 0.5
local last_chunk = {}

---------------------------------------------------------
-- PARTICULAS DE BORDA DO CHUNK
---------------------------------------------------------
local function spawn_border_particle(pos, color)
    minetest.add_particle({
        pos = pos,
        velocity = {x = 0, y = 0, z = 0},
        acceleration = {x = 0, y = 0, z = 0},
        expirationtime = 1,
        size = 2,
        collisiondetection = false,
        vertical = false,
        texture = "default_stone.png^[colorize:" .. (color or "#00FF00") .. ":255",
        glow = 10
    })
end

---------------------------------------------------------
-- MOSTRAR BORDAS DO CHUNK
---------------------------------------------------------
local function show_chunk_borders(player)
    local name = player:get_player_name()
    local pdata = PLAYERS_DATA[name]
    if not pdata or not pdata.show_territories then return end

    local pos = player:get_pos()
    local cid = get_chunk_id(pos)

    -- S� redesenha se entrou em outro chunk
    if last_chunk[name] == cid then return end
    last_chunk[name] = cid

    local cs = NATIONS.CHUNK_SIZE
    local cx = math.floor(pos.x / cs)
    local cz = math.floor(pos.z / cs)
    local chunk = CHUNKS_DATA[cid]

    local color = "#00FF00"

    if chunk and chunk.nation_id and pdata.nation_id then
        if chunk.nation_id ~= pdata.nation_id then
            color = "#FF0000"
        end
    end

    local x1 = cx * cs
    local z1 = cz * cs
    local x2 = x1 + cs
    local z2 = z1 + cs
    local y = pos.y + 1.5

    for x = x1, x2, 3 do
        spawn_border_particle({x = x, y = y, z = z1}, color)
        spawn_border_particle({x = x, y = y, z = z2}, color)
    end

    for z = z1, z2, 3 do
        spawn_border_particle({x = x1, y = y, z = z}, color)
        spawn_border_particle({x = x2, y = y, z = z}, color)
    end
end

---------------------------------------------------------
-- LOOP DAS BORDAS
---------------------------------------------------------
minetest.register_globalstep(function(dtime)
    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        timers[name] = (timers[name] or 0) + dtime

        if timers[name] >= 0.2 then
            timers[name] = 0
            show_chunk_borders(player)
        end
    end
end)

---------------------------------------------------------
-- HUD AO ENTRAR
---------------------------------------------------------
minetest.register_on_joinplayer(function(player)
    local name = player:get_player_name()

    huds[name] = player:hud_add({
        hud_elem_type = "text",
        position = {x = 0.5, y = 0.03},
        offset = {x = 0, y = 0},
        text = "",
        number = 0xFFFFFF,
        scale = {x = 150, y = 20},
        alignment = {x = 0, y = 0}
    })

    PLAYERS_DATA[name] = PLAYERS_DATA[name]
        or {nation_id = nil, rank = 0, show_territories = true}

    db_commit()
end)

minetest.register_on_leaveplayer(function(player)
    huds[player:get_player_name()] = nil
    last_chunk[player:get_player_name()] = nil
    timers[player:get_player_name()] = nil
end)

---------------------------------------------------------
-- TERRENO PRIVADO
---------------------------------------------------------
local function get_private_owner(chunk)
    if not chunk or not chunk.private then return nil end
    for owner, _ in pairs(chunk.private) do
        return owner
    end
    return nil
end

---------------------------------------------------------
-- ATUALIZAÇÃO DO HUD
---------------------------------------------------------
minetest.register_globalstep(function(dtime)
    update_timer = update_timer + dtime
    if update_timer < (NATIONS.HUD_UPDATE_INTERVAL or 0.5) then return end
    update_timer = 0

    for _, player in ipairs(minetest.get_connected_players()) do
        local name = player:get_player_name()
        local pdata = PLAYERS_DATA[name] or {}

        if not pdata.show_territories then
            if huds[name] then
                player:hud_change(huds[name], "text", "")
            end
        else
            local pos = player:get_pos()
            local cid = get_chunk_id(pos)
            local chunk = CHUNKS_DATA[cid]
            local txt = ""

            if chunk and chunk.nation_id and NATIONS_DATA[chunk.nation_id] then
                txt = "Território da Nação: " ..
                    NATIONS_DATA[chunk.nation_id].name
            else
                txt = "Território livre"
            end

            -- TERRENO PRIVADO
            local private_owner = get_private_owner(chunk)
            if private_owner then
                txt = txt .. "\n🏠 Terreno pessoal de: " .. private_owner
            end

            if huds[name] then
                player:hud_change(huds[name], "text", txt)
            end
        end
    end
end)