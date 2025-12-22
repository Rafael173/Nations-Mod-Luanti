local util = dofile(minetest.get_modpath(minetest.get_current_modname()).."/util.lua")

CHUNKS_DATA = CHUNKS_DATA or {}

-- Tamanho do chunk (ex: 31 = área 31x31)
local CHUNK_SIZE = NATIONS.CHUNK_SIZE or 11

---------------------------------------------------------
-- 📌 PEGAR ID DO CHUNK
---------------------------------------------------------
function get_chunk_id(pos)
    local size = NATIONS.CHUNK_SIZE
    local cx = math.floor(pos.x / size)
    local cz = math.floor(pos.z / size)
    return cx .. ":" .. cz
end

---------------------------------------------------------
-- 📌 VERIFICAR GUERRA
---------------------------------------------------------
function is_at_war(n1, n2)
    if not n1 or not n2 then return false end
    if not NATIONS_DATA[n1] or not NATIONS_DATA[n2] then return false end

    local dip = NATIONS_DATA[n1].diplomacy
        and NATIONS_DATA[n1].diplomacy[tostring(n2)]

    return dip == "guerra"
end
-- DOMINAR CHUNK (COM OCUPAÇÃO)
function dominate_chunk(player)
    if not player then
        return false, "Jogador inválido."
    end

    local pname = player:get_player_name()
    local pdata = PLAYERS_DATA[pname]

    if not pdata or not pdata.nation_id then
        return false, "Você não pertence a uma nação."
    end

    -- Apenas líder ou sublíder
    if pdata.rank < 4 then
        return false, "Apenas líderes ou sublíderes podem dominar territórios."
    end

    local nation = NATIONS_DATA[pdata.nation_id]
    if not nation then
        return false, "Erro interno: nação não encontrada."
    end

    -- Pontos
    nation.points = nation.points or 0
    local cost = NATIONS.DOMINATE_COST or 5

    if nation.points < cost then
        return false, "Sua nação não possui pontos suficientes para dominar território."
    end

    -- Chunk atual
    local pos = player:get_pos()
    local cid = get_chunk_id(pos)
    local chunk = CHUNKS_DATA[cid]

    -- Se for território inimigo, precisa estar em guerra
    if chunk and chunk.nation_id and chunk.nation_id ~= pdata.nation_id then
        if not is_at_war(pdata.nation_id, chunk.nation_id) then
            return false, "Você só pode dominar territórios inimigos durante uma guerra."
        end
    end

    -- Dominar / ocupar
    if not CHUNKS_DATA[cid] then
    CHUNKS_DATA[cid] = {}
	end
	
	local c = CHUNKS_DATA[cid]
	
	-- salvar origem se for ocupa��o
	if c.nation_id and c.nation_id ~= pdata.nation_id then
	    c.occupied_from = c.nation_id
	else
	    c.occupied_from = nil
	end
	
	c.nation_id = pdata.nation_id
	c.private = c.private or {}

    -- Consumir pontos
    nation.points = nation.points - cost

    db_commit()

    return true, ("Território dominado com sucesso. (-%d pontos)"):format(cost)
end


---------------------------------------------------------
-- 📌 CEDER CHUNK PARA JOGADOR
---------------------------------------------------------
function cede_chunk_to_player(player, target_name)
    if not player then return false, "Jogador inválido." end

    local pname = player:get_player_name()
    local pdata = PLAYERS_DATA[pname]

    if not pdata or not pdata.nation_id then
        return false, "Você não pertence a nenhuma nação."
    end

    if pdata.rank < 4 then
        return false, "Apenas sublíderes ou líderes podem ceder terrenos."
    end

    local tdata = PLAYERS_DATA[target_name]
    if not tdata or tdata.nation_id ~= pdata.nation_id then
        return false, "O jogador não pertence à sua nação."
    end

    local cid = get_chunk_id(player:get_pos())
    local chunk = CHUNKS_DATA[cid]

    if not chunk or chunk.nation_id ~= pdata.nation_id then
        return false, "Você não está em território da sua nação."
    end

    chunk.private = chunk.private or {}
    chunk.private[target_name] = true

    db_commit()
    return true, "Terreno cedido para " .. target_name .. "."
end

---------------------------------------------------------
-- 📌 REVOGAR TERRENO
---------------------------------------------------------
function revoke_chunk_from_player(player, target_name)
    if not player then return false, "Jogador inválido." end

    local pname = player:get_player_name()
    local pdata = PLAYERS_DATA[pname]

    if not pdata or not pdata.nation_id then
        return false, "Você não pertence a nenhuma nação."
    end

    if pdata.rank < 4 then
        return false, "Apenas sublíderes ou líderes podem revogar terrenos."
    end

    local cid = get_chunk_id(player:get_pos())
    local chunk = CHUNKS_DATA[cid]

    if not chunk or chunk.nation_id ~= pdata.nation_id then
        return false, "Você não está em território da sua nação."
    end

    if chunk.private and chunk.private[target_name] then
        chunk.private[target_name] = nil
        db_commit()
        return true, "Terreno de " .. target_name .. " foi revogado."
    end

    return false, "Esse jogador não possui terreno neste território."
end