-- nations/init.lua
local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
local permissions = dofile(minetest.get_modpath(minetest.get_current_modname()).."/permissions.lua")

dofile(modpath.."/config.lua")
dofile(modpath.."/database.lua")
dofile(modpath.."/util.lua")
dofile(modpath.."/permissions.lua")
dofile(modpath.."/chunks.lua")
dofile(modpath.."/points.lua")
dofile(modpath.."/diplomacy.lua")
dofile(modpath.."/chat.lua")
dofile(modpath.."/hud.lua")
dofile(modpath.."/commands.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()).."/war.lua")
dofile(minetest.get_modpath(minetest.get_current_modname()) .. "/map.lua")


minetest.log("action", "["..modname.."] loaded. Nations mod initialized.")



-- Bloqueio universal de construção
minetest.register_on_placenode(function(pos, newnode, placer, oldnode, itemstack, pointed_thing)
    if not placer then return end
    local ok, msg = can_build(placer, pos)
    if not ok then
        minetest.chat_send_player(placer:get_player_name(), msg)
        return true -- CANCELA a colocação do bloco
    end
end)

minetest.is_protected = function(pos, name)
    local player = minetest.get_player_by_name(name)
    if not player then
        return true
    end

    local ok = can_build(player, pos)
    return not ok
end

minetest.register_on_dignode(function(pos, oldnode, digger)
    if not digger then return end

    local ok, msg = can_build(digger, pos)
    if not ok and msg then
        minetest.chat_send_player(digger:get_player_name(), msg)
    end
end)