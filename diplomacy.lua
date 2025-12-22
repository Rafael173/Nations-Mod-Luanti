dofile(minetest.get_modpath(minetest.get_current_modname()).."/war.lua")

function set_diplomacy_between(n1, n2, relation)
    relation = string.lower(relation)

    if not NATIONS_DATA[n1] or not NATIONS_DATA[n2] then
        return false, "Nação inválida."
    end

    NATIONS_DATA[n1].diplomacy = NATIONS_DATA[n1].diplomacy or {}
    NATIONS_DATA[n2].diplomacy = NATIONS_DATA[n2].diplomacy or {}

    if relation == "guerra" then
        return start_war(n1, n2)

    elseif relation == "paz" then
        return true, "Pedido de paz enviado. A outra nação precisa aceitar."

    elseif relation == "aliado" then
        if is_at_war(n1, n2) then
            return false, "Não é possível virar aliado durante uma guerra."
        end
    end

    NATIONS_DATA[n1].diplomacy[tostring(n2)] = relation
    NATIONS_DATA[n2].diplomacy[tostring(n1)] = relation

    db_commit()
    return true, "Diplomacia atualizada."
end