local function ConcatToString(parts)
    for i, part in ipairs(parts) do
        parts[i] = tostring(part)
    end

    return table.concat(parts, "")
end

function stp.Error(...)
    error(ConcatToString({...}), 2)
end

function stp.ToString(val, pretty_print)
    pretty_print = pretty_print or false

    if val == nil then
        return "nil"
    elseif istable(val) then
        local meta = debug.getmetatable(val)
        if meta == nil or meta.__tostring == nil then
            return table.ToString(val, nil, pretty_print)
        end
    end

    return tostring(val)
end

local types = stp.GetPersistedTable("stp.core.debug.Types", {})

function stp.RegisterType(name, tbl)
    assert(isstring(name), "'name' is not a string")
    assert(istable(tbl), "'tbl' is not a table")

    local checker = tbl.IsInstance
    assert(isfunction(checker), "'tbl.IsInstance' is not a function")

    types[name] = checker
end

function stp.CheckType(val, valname, allowed_types)
    if isstring(allowed_types) then allowed_types = {allowed_types} end

    if stp.IsAnyType(val, allowed_types)
        return val
    end

    error(ConcatToString({
        "'",valname,"' is not a ",table.concat(allowed_types, "|"),",\n",
        "it is a [",type(val),"] ",stp.ToString(val, true)
    }), 2)
end

function stp.IsType(val, type)
    local checker = types[type]
    if checker == nil then return false end

    return checker(val)
end

function stp.IsAnyType(val, types)
    for _, ty in ipairs(types) do
        if types[ty](val) then
            return true 
        end
    end
    return false
end

stp.RegisterType("nil", { IsInstance = function(v) return v == nil end})
stp.RegisterType("number", { IsInstance = function(v) return isnumber(v) end})
stp.RegisterType("string", { IsInstance = function(v) return isstring(v) end})
stp.RegisterType("table", { IsInstance = function(v) return istable(v) end})
stp.RegisterType("bool", { IsInstance = function(v) return isbool(v) end})
stp.RegisterType("function", { IsInstance = function(v) return isfunction(v) end})
stp.RegisterType("Entity", { IsInstance = function(v) return IsEntity(v) end})
stp.RegisterType("Player", { IsInstance = function(v) return IsEntity(v) and v:IsPlayer() end})
stp.RegisterType("Panel",  { IsInstance = function(v) return ispanel(v) end})
stp.RegisterType("Vector", { IsInstance = function(v) return isvector(v) end})
stp.RegisterType("Angle", { IsInstance = function(v) return isangle(v) end})
stp.RegisterType("Matrix", { IsInstance = function(v) return ismatrix(v) end})