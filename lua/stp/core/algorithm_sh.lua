

function table.ReverseInplace(tbl)
    local midpoint = math.floor(#tbl/2)

    for i = 1, midpoint do
        local i2 = #tbl + 1 - i

        local temp = tbl[i]
        tbl[i] = tbl[i2]
        tbl[i2] = temp
    end
end

function table.SeqCount(tbl)
    local i = 0

    repeat
        i = i + 1
    until tbl[i] == nil

    return i - 1
end

function table.SeqFindValue(tbl, value)
    for i, val in ipairs(tbl) do
        if val == value then return i end
    end

    return nil
end


function table.RemoveFastByValue(tbl, value)
    for i, v in ipairs(tbl) do
        if v == value then
            tbl[i] = tbl[#tbl]
            tbl[#tbl] = nil

            return i
        end
    end
end