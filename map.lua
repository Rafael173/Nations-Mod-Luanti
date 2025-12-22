-- nations/map.lua

---------------------------------------------------------
-- CONFIGURACAO
---------------------------------------------------------
local MAP_RADIUS = 4 -- 4 = mapa 9x9

---------------------------------------------------------
-- PEGAR MAPA DE CHUNKS
---------------------------------------------------------
function get_nation_map(player)
    local name = player:get_player_name()
    local pdata = PLAYERS_DATA[name]

    local pos = player:get_pos()
    local cs = NATIONS.CHUNK_SIZE

    local cx = math.floor(pos.x / cs)
    local cz = math.floor(pos.z / cs)

    local lines = {}

    for z = cz - MAP_RADIUS, cz + MAP_RADIUS do
        local line = ""

        for x = cx - MAP_RADIUS, cx + MAP_RADIUS do
            local cid = x .. ":" .. z
            local chunk = CHUNKS_DATA[cid]

            local char = "."

            if x == cx and z == cz then
                char = "P"
            elseif chunk and chunk.nation_id then
                if pdata and pdata.nation_id then
                    if chunk.nation_id == pdata.nation_id then
                        char = "N"
                    elseif is_at_war(pdata.nation_id, chunk.nation_id) then
                        char = "E"
                    else
                        char = "A"
                    end
                else
                    char = "O"
                end
            end

            line = line .. char .. " "
        end

        table.insert(lines, line)
    end

    return table.concat(lines, "\n")
end

---------------------------------------------------------
-- FORMSPEC DO MAPA
---------------------------------------------------------
function show_nation_map(player)
    local map = get_nation_map(player)

    local formspec =
        "formspec_version[4]" ..
        "size[10,10]" ..
        "label[0.3,0.3;Mapa de Territorios]" ..
        "textarea[0.3,0.8;9.5,7.8;map;;" .. minetest.formspec_escape(map) .. "]" ..
        "label[0.3,8.8;Legenda: P=Voce  N=Sua Nacao  E=Inimigo  A=Aliado  .=Livre]"

    minetest.show_formspec(
        player:get_player_name(),
        "nations:map",
        formspec
    )
end