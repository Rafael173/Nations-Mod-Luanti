-- nations/points.lua
local timer = 0

minetest.register_globalstep(function(dtime)
    timer = timer + dtime
    if timer < NATIONS.POINTS_TICK_SECONDS then return end
    timer = 0

    for id, nation in pairs(NATIONS_DATA) do
        -- contar membros online
        local online = false
        local members_count = nation.members or 0
        for pname, pdata in pairs(PLAYERS_DATA) do
            if pdata.nation_id == id and minetest.get_player_by_name(pname) then
                online = true
                break
            end
        end

        if online then
            local max_points = NATIONS.BASE_POINTS + ( (nation.members or 0) * NATIONS.POINTS_PER_MEMBER )
            nation.points = (nation.points or 0)
            if nation.points < max_points then
                nation.points = nation.points + 1
            end
        end
    end

    db_commit()
end)