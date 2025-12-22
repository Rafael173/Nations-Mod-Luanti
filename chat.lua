-- nations/chat.lua

function send_nation_chat(sender_name, message)
    local pdata = PLAYERS_DATA[sender_name]
    if not pdata or not pdata.nation_id then
        return false, "Você não pertence a nenhuma nação."
    end
    local nid = pdata.nation_id
    for pname, pdata2 in pairs(PLAYERS_DATA) do
        if pdata2.nation_id == nid and minetest.get_player_by_name(pname) then
            minetest.chat_send_player(pname, ("[Nação %s] %s: %s"):format(NATIONS_DATA[nid].name or tostring(nid), sender_name, message))
        end
    end
    return true
end