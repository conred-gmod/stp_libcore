local function ConcatToString(parts)
    for i, part in ipairs(parts) do
        parts[i] = tostring(part)
    end

    return table.concat(parts, "")
end

function STPLib.Error(...)
    error(ConcatToString({...}), 2)
end

function STPLib.ToString(val, pretty_print)
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

local types = types or {}

function STPLib.RegisterType(name, tbl)
    assert(isstring(name), "'name' is not a string")
    assert(istable(tbl), "'tbl' is not a table")

    local checker = tbl.IsInstance
    assert(isfunction(checker), "'tbl.IsInstance' is not a function")

    types[name] = checker
end

function STPLib.CheckType(val, valname, allowed_types)
    if isstring(allowed_types) then allowed_types = {allowed_types} end

    for _, allowed_ty in ipairs(allowed_types) do
        if types[allowed_ty](val) then
            return val
        end
    end

    error(ConcatToString({
        "'",valname,"' is not a ",table.concat(allowed_types, "|"),",\n",
        "it is a [",type(val),"] ",STPLib.ToString(val, true)
    }), 2)
end

function STPLib.IsType(val, type)
    local checker = types[type]
    if checker == nil then return false end

    return checker(val)
end

STPLib.RegisterType("nil", { IsInstance = function(v) return v == nil end})
STPLib.RegisterType("number", { IsInstance = function(v) return isnumber(v) end})
STPLib.RegisterType("string", { IsInstance = function(v) return isstring(v) end})
STPLib.RegisterType("table", { IsInstance = function(v) return istable(v) end})
STPLib.RegisterType("bool", { IsInstance = function(v) return isbool(v) end})
STPLib.RegisterType("function", { IsInstance = function(v) return isfunction(v) end})
STPLib.RegisterType("Entity", { IsInstance = function(v) return IsEntity(v) end})
STPLib.RegisterType("Player", { IsInstance = function(v) return IsEntity(v) and v:IsPlayer() end})
STPLib.RegisterType("Panel",  { IsInstance = function(v) return ispanel(v) end})
STPLib.RegisterType("Vector", { IsInstance = function(v) return isvector(v) end})
STPLib.RegisterType("Angle", { IsInstance = function(v) return isangle(v) end})
STPLib.RegisterType("Matrix", { IsInstance = function(v) return ismatrix(v) end})