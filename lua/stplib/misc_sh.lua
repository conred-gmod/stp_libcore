local table_insert = table.insert
local table_remove = table.remove
local table_IsEmpty = table.IsEmpty


function STPLib.ReverseArrayInplace(tbl)
    local midpoint = math.floor(#tbl/2)

    for i = 1, midpoint do
        local i2 = #tbl + 1 - i

        local temp = tbl[i]
        tbl[i] = tbl[i2]
        tbl[i2] = temp
    end
end
local STPLib_ReverseArrayInplace = STPLib.ReverseArrayInplace

function STPLib.IndexWithFill(tbl, ...)
    local keys = {...}

    for i = #keys, 1, -1 do
        local key = keys[i]

        if tbl[key] == nil then
            tbl[key] = {}
        end

        tbl = tbl[key]
    end

    return tbl
end
local STPLib_IndexWithFill = STPLib.IndexWithFill


function STPLib.AddToTable(tbl, value, ...)
    local keys = {...}

    local lastkey = table_remove(keys)

    local lasttbl = STPLib_IndexWithFill(tbl, unpack(keys))

    lasttbl[lastkey] = value
end

function STPLib.AddToArray(tbl, value, ...)
    local lasttbl = STPLib_IndexWithFill(tbl, ...)

    table_insert(lasttbl, value)
end

local function CascadeRemove(keys, child_stack)
    STPLib_ReverseArrayInplace(keys)
    STPLib_ReverseArrayInplace(child_stack)

    for i, key in ipairs(keys) do
        if not table_IsEmpty(child_stack[i]) then
            return
        end

        child_stack[i+1][key] = nil
    end
end

function STPLib.RemoveFromTable(tbl, ...)
    local keys = {...}
    local child_stack = {}

    local lastkey = table_remove(keys)

    for i, key in ipairs(keys) do
        child_stack[i] = tbl
        tbl = tbl[key]
    end

    table_insert(child_stack, tbl)

    tbl[lastkey] = nil

    CascadeRemove(keys, child_stack)
end