-- nations/commands.lua
local util = dofile(minetest.get_modpath(minetest.get_current_modname()).."/util.lua")

local function is_leader(playername)
    local pdata = PLAYERS_DATA[playername]
    return pdata and (pdata.rank == 5)
end

local function is_sublider_or_leader(playername)
    local pdata = PLAYERS_DATA[playername]
    return pdata and (pdata.rank >= 4)
end

---------------------------------------------------------
-- CRIAR NAÇÃO
---------------------------------------------------------
local function create_nation(playername, nation_name)
    if not nation_name or nation_name == "" then
        return false, "Use: /nation criar <nome da nação>"
    end

    local id = db_get_next_id()

    NATIONS_DATA[id] = {
        id = id,
        name = nation_name,
        members = 1,
        points = NATIONS.BASE_POINTS,
        diplomacy = {},
        capital = nil
    }

    PLAYERS_DATA[playername] = {
        nation_id = id,
        rank = 5,
        show_territories = true
    }

    db_commit()

    return true, ("Nação criada: %s (id %d). Você agora é o líder."):format(nation_name, id)
end

---------------------------------------------------------
-- FUNÇÕES PARA DELETAR NAÇÃO
---------------------------------------------------------

local function nation_has_chunks(nation_id)
    for _, chunk in pairs(CHUNKS_DATA) do
        if chunk.nation_id == nation_id then
            return true
        end
    end
    return false
end

local function nation_is_at_war(nation_id)
    if not NATIONS_DATA[nation_id] then return false end

    local dip = NATIONS_DATA[nation_id].diplomacy or {}
    for _, status in pairs(dip) do
        if status == "guerra" then
            return true
        end
    end
    return false
end

local function dissolve_nation(playername)
    local pdata = PLAYERS_DATA[playername]
    if not pdata or not pdata.nation_id then
        return false, "Você não pertence a nenhuma nação."
    end

    if pdata.rank < 5 then
        return false, "Apenas o líder pode dissolver a nação."
    end

    local nid = pdata.nation_id
    local nation = NATIONS_DATA[nid]
    if not nation then
        return false, "Erro interno: nação não encontrada."
    end

    -- Tem territórios
    if nation_has_chunks(nid) then
        return false, "A nação possui territórios dominados e não pode ser dissolvida."
    end

    -- Está em guerra
    if nation_is_at_war(nid) then
        return false, "A nação está em guerra e não pode ser dissolvida."
    end

    -- Remover jogadores da nação
    for pname, p in pairs(PLAYERS_DATA) do
        if p.nation_id == nid then
            p.nation_id = nil
            p.rank = nil
        end
    end

    -- Limpar diplomacia de outras nações
    for _, other in pairs(NATIONS_DATA) do
        if other.diplomacy then
            other.diplomacy[tostring(nid)] = nil
        end
    end

    -- Limpar guerra (se existir WAR_DATA)
    WAR_DATA[nid] = nil
    for _, wars in pairs(WAR_DATA) do
        wars[tostring(nid)] = nil
    end

    -- Apagar nação
    NATIONS_DATA[nid] = nil

    db_commit()
    return true, "A nação foi dissolvida com sucesso."
end

function show_dissolve_nation_formspec(playername, nation)
    local fs = table.concat({
        "formspec_version[4]",
        "size[12,8]",

        
        "background[0,0;12,8;menu_background.png;true]",

        
        "image[4.5,0.2;3,1.2;logo.png]",

        
        "label[3.5,1.6;⚠ Dissolver Nação]",

        
        "label[1,2.5;Você está prestes a dissolver sua nação.]",
        "label[1,3.1;Essa ação é PERMANENTE e NÃO poderá ser desfeita.]",

        
        "label[1,4.1;Nação: " .. minetest.formspec_escape(nation.name) .. "]",
        "label[1,4.7;Membros: " .. tostring(nation.members or 0) .. "]",
        "label[1,5.3;Pontos: " .. tostring(nation.points or 0) .. "]",

        
        "label[1,6.2;• Você perderá a sua liderança]",

        
        "box[0.5,6.9;11,0.05;#555555]",
		"button_exit[1.2,7.1;4,0.9;cancel;Cancelar]",
		"button[6.8,7.1;4,0.9;confirm_dissolve;Confirmar Dissolução]"
    })

    minetest.show_formspec(playername, "nations:dissolve_confirm", fs)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "nations:dissolve_confirm" then return end

    local name = player:get_player_name()
    local pdata = PLAYERS_DATA[name]
    if not pdata or not pdata.nation_id then return end

    local nation = NATIONS_DATA[pdata.nation_id]
    if not nation then return end

    if fields.confirm_dissolve then
        local ok, msg = dissolve_nation(name)
        minetest.chat_send_player(name, ok and msg or ("Erro: " .. msg))
    end
end)


---------------------------------------------------------
-- LISTAR NAÇÕES
---------------------------------------------------------
local function list_nations(playername)
    if not next(NATIONS_DATA) then
        minetest.chat_send_player(playername, "Nenhuma nação criada.")
        return
    end

    local lines = {}
    local i = 0

    for id, nation in pairs(NATIONS_DATA) do
        -- contar população
        local pop = 0
        for _, p in pairs(PLAYERS_DATA) do
            if p.nation_id == id then
                pop = pop + 1
            end
        end

        -- contar territórios
        local territories = 0
        for _, c in pairs(CHUNKS_DATA) do
            if c.nation_id == id then
                territories = territories + 1
            end
        end

        lines[#lines + 1] =
            minetest.formspec_escape(
                string.format(
                    "[%d] %s | Pop: %d | Territórios: %d | Pontos: %d",
                    id,
                    nation.name,
                    pop,
                    territories,
                    nation.points or 0
                )
            )

        i = i + 1
    end

    local formspec =
        "formspec_version[4]" ..
        "size[14,10]" ..

        
        "background[0,0;14,10;menu_background.png]" ..

        
        "image[5,0.2;4,1.5;logo.png]" ..

        
        "box[0.3,2.0;13.4,7.2;#111111AA]" ..

        
        "label[0.6,2.1;Lista de Nações do Servidor]" ..

        
        "textlist[0.6,2.7;12.8,5.8;nations_list;" ..
        table.concat(lines, ",") .. "]" ..

        
        "button_exit[5,8.7;4,1;exit;Fechar]"

    minetest.show_formspec(playername, "nations:list", formspec)
end

---------------------------------------------------------
-- ENTRAR NA NAÇÃO
---------------------------------------------------------
local function join_nation(playername, nid)
    local n = NATIONS_DATA[tonumber(nid)]
    if not n then return false, "Nação inexistente." end

    PLAYERS_DATA[playername] = PLAYERS_DATA[playername] or {}
    PLAYERS_DATA[playername].nation_id = tonumber(nid)
    PLAYERS_DATA[playername].rank = PLAYERS_DATA[playername].rank or 0

    n.members = (n.members or 0) + 1

    db_commit()
    return true, ("Você entrou na nação %s (id %d)."):format(n.name, n.id)
end

---------------------------------------------------------
-- SAIR DA NAÇÃO
---------------------------------------------------------
local function leave_nation(playername)
    local pdata = PLAYERS_DATA[playername]
    if not pdata or not pdata.nation_id then
        return false, "Você não pertence a nenhuma nação."
    end

    local nid = pdata.nation_id
    local nation = NATIONS_DATA[nid]

    if pdata.rank == 5 then
        return false, "O líder não pode sair da nação. Transfira liderança primeiro."
    end

    -- Remover terrenos privados
    for cid, chunk in pairs(CHUNKS_DATA) do
        if chunk.nation_id == nid and chunk.private and chunk.private[playername] then
            chunk.private[playername] = nil
        end
    end

    nation.members = math.max((nation.members or 1) - 1, 0)

    PLAYERS_DATA[playername] = {nation_id = nil, rank = 0, show_territories = true}

    db_commit()
    return true, "Você saiu da nação. Seus terrenos privados foram removidos."
end

---------------------------------------------------------
-- PROMOVER JOGADOR
---------------------------------------------------------
local function promote_player(issuer, target_name, rank_str)
    local issuer_data = PLAYERS_DATA[issuer]
    if not issuer_data or issuer_data.rank ~= 5 then
        return false, "Apenas líderes podem promover membros."
    end

    if not PLAYERS_DATA[target_name]
    or PLAYERS_DATA[target_name].nation_id ~= issuer_data.nation_id then
        return false, "O jogador alvo não pertence à sua nação."
    end

    local rank = tonumber(rank_str)
    if not rank or rank < 0 or rank > 4 then
        return false, "Rank inválido. Use 0..4."
    end

    PLAYERS_DATA[target_name].rank = rank
    db_commit()

    return true, ("Jogador %s promovido para rank %d."):format(target_name, rank)
end

---------------------------------------------------------
-- CHAT DA NAÇÃO
---------------------------------------------------------
local function nation_chat_cmd(playername, message)
    if not message or message == "" then
        return false, "Use: /nation chat <mensagem>"
    end
    return send_nation_chat(playername, message)
end

---------------------------------------------------------
-- DIPLOMACIA
---------------------------------------------------------
local function diplomacy_cmd(playername, flag, other_id)
    local pdata = PLAYERS_DATA[playername]
    if not pdata or not pdata.nation_id then return false, "Você não pertence a nenhuma nação." end

    local nid = pdata.nation_id
    local other = tonumber(other_id)
    if not NATIONS_DATA[other] then return false, "Nação alvo não existe." end

    local nation = NATIONS_DATA[nid]
    if nation.points < NATIONS.DIPLOMACY_COST then
        return false, "Sua nação não tem pontos suficientes."
    end

    local ok, msg = set_diplomacy_between(nid, other, flag)
    if ok then
        nation.points = nation.points - NATIONS.DIPLOMACY_COST
        db_commit()
    end
    return ok, msg
end

---------------------------------------------------------
-- TOGGLE DE HUD
---------------------------------------------------------
local function toggle_territories(playername)
    PLAYERS_DATA[playername] = PLAYERS_DATA[playername] or {nation_id = nil, rank = 0, show_territories = true}
    local cur = PLAYERS_DATA[playername].show_territories

    PLAYERS_DATA[playername].show_territories = not cur
    db_commit()

    return true,
        ("Visualização dos territórios agora está: %s")
        :format(PLAYERS_DATA[playername].show_territories and "ATIVA" or "DESATIVADA")
end

---------------------------------------------------------
-- CEDER / REVOGAR TERRENO
---------------------------------------------------------
local function cede_cmd(playername, target)
    local player = minetest.get_player_by_name(playername)
    if not player then return false, "Jogador não encontrado." end
    return cede_chunk_to_player(player, target)
end

local function revogar_cmd(playername, target)
    local player = minetest.get_player_by_name(playername)
    if not player then return false, "Jogador não encontrado." end
    return revoke_chunk_from_player(player, target)
end


function show_nation_help_formspec(name)
    local fs = table.concat({
        "formspec_version[4]",
        "size[14,9]",
        "background[0,0;14,9;menu_background.png;true]",

        -- Logo
        "image[5,0.3;4,1.2;logo.png]",

        -- Título
        "label[4.2,1.6;Ajuda - Sistema de Nações]",

        -- Scrollbar
        "scrollbar[13.5,2;0.4,6;vertical;help_scroll;0]",

        -- Scroll container (altura grande para permitir rolagem)
        "scroll_container[0.5,2;12.8,6;help_scroll;vertical]",

            "label[0,0;COMANDOS DISPONÍVEIS]",

            "label[0,0.8;/nation criar <nome>\nCria uma nova nação]",

            "label[0,1.8;/nation dissolver\nDissolve sua nação (apenas líder)]",

            "label[0,2.8;/nation map\nMostra o mapa das nações]",

            "label[0,3.8;/nation dominar\nDomina o território atual]",

            "label[0,4.8;/nation list\nLista todas as nações]",

            "label[0,5.8;/nation entrar <id>\nEntra em uma nação]",

            "label[0,6.8;/nation promover <player> <rank>\nPromove membros]",

            "label[0,7.8;/nation sair\nSai da nação]",

            "label[0,8.8;/nation chat <msg>\nChat interno da nação]",

            "label[0,9.8;/nation diplomacia <acao> <id>\nGuerra, paz ou alianças]",

            "label[0,10.8;/nation territorios\nAtiva HUD de territórios]",

            "label[0,11.8;/nation ceder <player>\nCede terrenos]",

            "label[0,12.8;/nation revogar <player>\nRevoga terrenos]",

            "label[0,13.8;/nation setcapital\nDefine capital da nação]",

            "label[0,14.8;/nation capital\nTeleporta para a capital]",

            "label[0,15.8;/nation status\nMostra status da nação]",

        -- FECHAMENTO OBRIGATÓRIO
        "scroll_container_end[]",

        -- Botão fechar
        "button_exit[5.5,8.3;3,0.7;exit;Fechar]"
    })

    minetest.show_formspec(name, "nation:help", fs)
end



-- Créditos pela criação do Mod, favor não apagar pois deu trabalho para fazer todo o Mod além disso, ele é fornecido de forma gratuita para uso, então remover os créditos é desrespeitoso e imoral.
minetest.register_chatcommand("creditos", {
    description = "Mostra os créditos do mod Nations",
    func = function(playername)

        local formspec =
            "formspec_version[4]" ..
            "size[14,9]" ..

            
            "background[0,0;14,9;menu_background.png]" ..

            
            "box[0.4,0.4;13.2,8.2;#0F0F0FCC]" ..

            
            "label[5.1,0.8;NATIONS MOD]" ..
            "style[label;font_size=20]" ..

            
            "label[4.3,1.4;Sistema de Nações, Territórios e Guerra]" ..

            
            "box[1,2.0;12,0.05;#FFFFFF44]" ..

            
            "label[1.2,2.5;Desenvolvedor: Rafael.Dev]" ..
            "label[1.2,3.1;Projeto: Nations Mod para Luanti]" ..
            "label[1.2,3.8;Principais recursos:]" ..

            "label[1.6,4.3;• Criação e gerenciamento de nações]" ..
            "label[1.6,4.8;• Sistema de territórios (chunks / claims)]" ..
            "label[1.6,5.3;• Diplomacia, guerras e dominação]" ..
            "label[1.6,5.8;• Pontuação e controle territorial]" ..

            
            "box[1,6.4;12,0.05;#FFFFFF44]" ..

            
            "label[3.9,6.9;Projeto independente desenvolvido no Brasil]" ..

            
            "button_url[4.2,7.5;5.5,1.1;discord;Entrar no Discord;https://discord.gg/jfwrGwmnky]" ..

            
            "button_exit[10.1,7.5;2.5,1.1;exit;Fechar]"

        minetest.show_formspec(playername, "nations:creditos", formspec)
    end
})


---------------------------------------------------------
-- REGISTRO DO COMANDO /nation
---------------------------------------------------------
minetest.register_chatcommand("nation", {
    params = "<subcomando>",
    description = "Comandos de Nações",
    func = function(name, param)

        local args = util.split_params(param)
        local sub = args[1] or ""

        -----------------------------------------------------
        -- CRIAR
        -----------------------------------------------------
        if sub == "criar" then
            table.remove(args,1)
            local nm = table.concat(args, " ")
            local ok, msg = create_nation(name, nm)
            minetest.chat_send_player(name, ok and msg or ("Erro: " .. msg))
            return true
            
        -----------------------------------------------------
        -- CRIAR
        -----------------------------------------------------
        
		elseif sub == "dissolver" then
		    local pdata = PLAYERS_DATA[name]
		    if not pdata or not pdata.nation_id then
		        minetest.chat_send_player(name, "Você não pertence a nenhuma nação.")
		        return true
		    end
		
		    if pdata.rank < 5 then
		        minetest.chat_send_player(name, "Apenas o líder pode dissolver a nação.")
		        return true
		    end
		
		    local nation = NATIONS_DATA[pdata.nation_id]
		    if not nation then
		        minetest.chat_send_player(name, "Erro interno: nação não encontrada.")
		        return true
		    end
		
		    show_dissolve_nation_formspec(name, nation)
		    return true
            
		-----------------------------------------------------
		-- AJUDA
		-----------------------------------------------------
		elseif sub == "ajuda" then
		    show_nation_help_formspec(name)
		    return true
            
        ------------------------------------------------------
        -- MAP
        ------------------------------------------------------
            
        elseif sub == "map" then
		    local player = minetest.get_player_by_name(name)
		    if not player then
		        minetest.chat_send_player(name, "Jogador invalido.")
		        return true
		    end
		
		    show_nation_map(player)
		    return true

        -----------------------------------------------------
        -- DOMINAR
        -----------------------------------------------------
        elseif sub == "dominar" then
            local player = minetest.get_player_by_name(name)
            local ok, msg = dominate_chunk(player)
            minetest.chat_send_player(name, ok and msg or ("Erro: " .. msg))
            return true

        -----------------------------------------------------
        -- LISTAR
        -----------------------------------------------------
        elseif sub == "list" then
            list_nations(name)
            return true

        -----------------------------------------------------
        -- ENTRAR
        -----------------------------------------------------
        elseif sub == "entrar" then
            if not args[2] then
                minetest.chat_send_player(name, "Use: /nation entrar <id>")
                return true
            end

            local ok, msg = join_nation(name, args[2])
            minetest.chat_send_player(name, ok and msg or ("Erro: " .. msg))
            return true

        -----------------------------------------------------
        -- PROMOVER
        -----------------------------------------------------
        elseif sub == "promover" then
            if not args[2] or not args[3] then
                minetest.chat_send_player(name, "Use: /nation promover <player> <rank>")
                return true
            end

            local ok, msg = promote_player(name, args[2], args[3])
            minetest.chat_send_player(name, ok and msg or ("Erro: " .. msg))
            return true

        -----------------------------------------------------
        -- SAIR
        -----------------------------------------------------
        elseif sub == "sair" then
            local ok, msg = leave_nation(name)
            minetest.chat_send_player(name, ok and msg or ("Erro: " .. msg))
            return true

        -----------------------------------------------------
        -- CHAT
        -----------------------------------------------------
        elseif sub == "chat" then
            table.remove(args,1)
            local msg = table.concat(args," ")
            local ok, msg2 = nation_chat_cmd(name, msg)
            if not ok then minetest.chat_send_player(name, "Erro: " .. msg2) end
            return true
-----------------------------------------------------
-- DIPLOMACIA
-----------------------------------------------------
        elseif sub == "diplomacia" then
            if not args[2] or not args[3] then
                minetest.chat_send_player(name,
                    "Use: /nation diplomacia <guerra|paz|aceitarpaz|aliado> <id>")
                return true
            end
        
            local pdata = PLAYERS_DATA[name]
            if not pdata or pdata.rank < 4 then
                minetest.chat_send_player(name,
                    "Apenas líderes ou sublíderes podem usar diplomacia.")
                return true
            end
        
            local other = tonumber(args[3])
            if not other or not NATIONS_DATA[other] then
                minetest.chat_send_player(name, "Nação alvo inválida.")
                return true
            end
        
            -- GUERRA
            if args[2] == "guerra" then
                local ok, msg = start_war(pdata.nation_id, other)
                minetest.chat_send_player(name, ok and msg or ("Erro: "..msg))
                return true
        
            -- ACEITAR PAZ
            elseif args[2] == "aceitarpaz" then
                local ok, msg = end_war(pdata.nation_id, other)
                minetest.chat_send_player(name, ok and msg or ("Erro: "..msg))
                return true
        
            -- PAZ / ALIADO
            else
                local ok, msg = set_diplomacy_between(
                    pdata.nation_id,
                    other,
                    args[2]
                )
                minetest.chat_send_player(name, ok and msg or ("Erro: "..msg))
                return true
            end
        


        -----------------------------------------------------
        -- HUD TERRITÓRIOS
        -----------------------------------------------------
        elseif sub == "territorios" then
            local ok, msg = toggle_territories(name)
            minetest.chat_send_player(name, msg)
            return true

        -----------------------------------------------------
        -- CEDER TERRENO
        -----------------------------------------------------
        elseif sub == "ceder" then
            if not args[2] then
                minetest.chat_send_player(name, "Use: /nation ceder <player>")
                return true
            end

            local ok, msg = cede_cmd(name, args[2])
            minetest.chat_send_player(name, ok and msg or ("Erro: " .. msg))
            return true

        -----------------------------------------------------
        -- REVOGAR TERRENO
        -----------------------------------------------------
        elseif sub == "revogar" then
            if not args[2] then
                minetest.chat_send_player(name,"Use: /nation revogar <player>")
                return true
            end

            local ok, msg = revogar_cmd(name, args[2])
            minetest.chat_send_player(name, ok and msg or ("Erro: " .. msg))
            return true

        -----------------------------------------------------
        -- DEFINIR CAPITAL
        -----------------------------------------------------
        elseif sub == "setcapital" then
            local pdata = PLAYERS_DATA[name]

            if not pdata or not pdata.nation_id then
                minetest.chat_send_player(name, "Você não pertence a nenhuma nação.")
                return true
            end

            if pdata.rank ~= 5 then
                minetest.chat_send_player(name, "Apenas o líder pode definir a capital.")
                return true
            end

            local nation = NATIONS_DATA[pdata.nation_id]
            if not nation then
                minetest.chat_send_player(name, "Erro interno: nação não encontrada.")
                return true
            end

            local player = minetest.get_player_by_name(name)
            local pos = player:get_pos()

            nation.capital = {
                x = math.floor(pos.x),
                y = math.floor(pos.y),
                z = math.floor(pos.z)
            }

            db_commit()

            minetest.chat_send_player(name,
                ("Capital definida em (%.1f, %.1f, %.1f).")
                :format(pos.x, pos.y, pos.z))

            return true

        -----------------------------------------------------
        -- TELEPORTAR PARA CAPITAL
        -----------------------------------------------------
        elseif sub == "capital" then
            local pdata = PLAYERS_DATA[name]

            if not pdata or not pdata.nation_id then
                minetest.chat_send_player(name, "Você não pertence a nenhuma nação.")
                return true
            end

            local nation = NATIONS_DATA[pdata.nation_id]

            if not nation or not nation.capital then
                minetest.chat_send_player(name, "Sua nação não definiu uma capital ainda.")
                return true
            end

            local player = minetest.get_player_by_name(name)

            player:set_pos({
                x = nation.capital.x + 0.5,
                y = nation.capital.y + 1,
                z = nation.capital.z + 0.5
            })

            minetest.chat_send_player(name, "Teleportado para a capital da sua nação.")
            return true

        -----------------------------------------------------
        -- CASO NÃO EXISTA
        -----------------------------------------------------
        
        -----------------------------------------------------
		-- STATUS DA NAÇÃO (formspec)
		-----------------------------------------------------
		elseif sub == "status" then
		    local pdata = PLAYERS_DATA[name]
		    if not pdata or not pdata.nation_id then
		        minetest.chat_send_player(name, "Você não pertence a nenhuma nação.")
		        return true
		    end
		
		    local nation = NATIONS_DATA[pdata.nation_id]
		    if not nation then
		        minetest.chat_send_player(name, "Erro: sua nação não foi encontrada.")
		        return true
		    end
		
		    -- calcular população
		    local pop = 0
		    for _, pl in pairs(PLAYERS_DATA) do
		        if pl.nation_id == pdata.nation_id then
		            pop = pop + 1
		        end
		    end
		
		    -- aliados
		    local aliados = {}
		    if nation.diplomacy then
		        for id, rel in pairs(nation.diplomacy) do
		            if rel == "ally" and NATIONS_DATA[id] then
		                table.insert(aliados, NATIONS_DATA[id].name)
		            end
		        end
		    end
		    aliados = #aliados > 0 and table.concat(aliados, ", ") or "Nenhum"
		
		    -- guerras
		    local guerras = {}
		    if nation.diplomacy then
		        for id, rel in pairs(nation.diplomacy) do
		            if rel == "war" and NATIONS_DATA[id] then
		                table.insert(guerras, NATIONS_DATA[id].name)
		            end
		        end
		    end
		    guerras = #guerras > 0 and table.concat(guerras, ", ") or "Nenhuma"
		
		    -- contar territórios
		    local territories = 0
		    for _, c in pairs(CHUNKS_DATA) do
		        if c.nation_id == pdata.nation_id then
		            territories = territories + 1
		        end
		    end
		
		    -- líder
		    local leader = "Indefinido"
		    for plname, pinfo in pairs(PLAYERS_DATA) do
		        if pinfo.nation_id == pdata.nation_id and pinfo.rank >= 4 then
		            leader = plname
		            break
		        end
		    end
		
		    -- formspec
		    local formspec =
		        "formspec_version[4]" ..
		        "size[14,10]" ..
		        "label[0.5,0.5;Status da Nacao]" ..
		        "box[0.3,0.9;13.4,8.6;#1A1A1A]" ..
		
		        ("label[0.6,1.2;Nome da nação: %s (ID: %d)]"):format(nation.name, pdata.nation_id) ..
		        ("label[9.5,1.2;Pontos: %d]"):format(nation.points or 0) ..
		
		        ("label[0.6,2.0;Lider: %s]"):format(leader) ..
		        ("label[7.0,2.0;População: %d habitante(s)]"):format(pop) ..
		
		        ("label[0.6,3.0;Territorios dominados: %d]"):format(territories) ..
		        ("label[0.6,4.0;Aliados: %s]"):format(aliados) ..
		        ("label[0.6,5.0;Guerras: %s]"):format(guerras) ..
		
		        "button_exit[5,8.5;4,1;ok;Fechar]"
		
		    minetest.show_formspec(name, "nations:status", formspec)
		    return true
        else
            minetest.chat_send_player(name, "Subcomando inválido. Use: /nation ajuda")
            return true
        end
    end
})