-- nations/permissions.lua
local util = dofile(minetest.get_modpath(minetest.get_current_modname()).."/util.lua")

-- ranks:
-- 0 = civil
-- 1 = soldado
-- 2 = builder
-- 3 = oficial
-- 4 = sublider
-- 5 = lider

------------------------------------------------------------
-- Função principal usada pelo sistema inteiro
-- can_build(player, pos)
------------------------------------------------------------

function can_build(player, pos)
    if not player or not pos then return false end

    local name = player:get_player_name()
    local pdata = PLAYERS_DATA[name]

    if not pdata or not pdata.nation_id then
        return false, "Você não pertence a nenhuma nação."
    end

    local nid = pdata.nation_id

    -- identificar o chunk
    local cx = math.floor(pos.x / NATIONS.CHUNK_SIZE)
    local cz = math.floor(pos.z / NATIONS.CHUNK_SIZE)
    local cid = cx .. ":" .. cz

    local chunk = CHUNKS_DATA[cid]

    -- território livre → ninguém constrói
    if not chunk then
        return false, "Esse território não pertence a nenhuma nação."
    end

    -- território pertence a outra nação
    if chunk.nation_id ~= nid then
        return false, "Esse território pertence a outra nação."
    end

    -- líder / sublíder / oficial / builder
    if pdata.rank >= 3 then
        return true
    end

    -- civil ou soldado → só terreno cedido
    if chunk.private and chunk.private[name] then
        return true
    end

    return false, "Você não tem permissão de construir aqui."
end

------------------------------------------------------------
-- Hooks para bloquear construção / destruição
------------------------------------------------------------

------------------------------------------------------------
-- Hooks CORRIGIDOS para versões antigas do Minetest
------------------------------------------------------------

minetest.register_on_placenode(function(pos, node, placer)
    if not placer then return end

    local ok, msg = can_build(placer, pos)
    if not ok then
        -- remove o node colocado
        minetest.remove_node(pos)

        -- devolve o item para o jogador
        local inv = placer:get_inventory()
        if inv then
            inv:add_item("main", node.name)
        end

        -- mensagem
        minetest.chat_send_player(placer:get_player_name(), msg or "Você não pode construir aqui.")

        return true
    end
end)


minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger then return end

    local ok, msg = can_build(digger, pos)
    if not ok then
        -- recoloca o node destruído
        minetest.set_node(pos, oldnode)

        -- mensagem
        minetest.chat_send_player(digger:get_player_name(), msg or "Você não pode destruir aqui.")

        return true
    end
end)