WAR_DATA = WAR_DATA or {}

function start_war(n1, n2)
    if n1 == n2 then
        return false, "Você não pode declarar guerra contra si mesmo."
    end

    WAR_DATA[n1] = WAR_DATA[n1] or {}
    WAR_DATA[n2] = WAR_DATA[n2] or {}

    WAR_DATA[n1][tostring(n2)] = true
    WAR_DATA[n2][tostring(n1)] = true

    NATIONS_DATA[n1].diplomacy[tostring(n2)] = "guerra"
    NATIONS_DATA[n2].diplomacy[tostring(n1)] = "guerra"

    db_commit()
    return true, "Guerra declarada com sucesso."
end

function is_at_war(n1, n2)
    return WAR_DATA[n1] and WAR_DATA[n1][tostring(n2)] == true
end

function end_war(n1, n2)
    if not is_at_war(n1, n2) then
        return false, "As nações não estão em guerra."
    end

    WAR_DATA[n1][tostring(n2)] = nil
    WAR_DATA[n2][tostring(n1)] = nil

    NATIONS_DATA[n1].diplomacy[tostring(n2)] = "paz"
    NATIONS_DATA[n2].diplomacy[tostring(n1)] = "paz"

    db_commit()
    return true, "A guerra foi encerrada. A paz foi estabelecida."
end