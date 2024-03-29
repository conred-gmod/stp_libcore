local function ConcatToString(...)
    local parts = {...}
    for i = 1, select("#", ...) do
        parts[i] = tostring(parts[i])
    end

    return table.concat(parts, "")
end

function stp.Error(...)
    error(ConcatToString(...), 2)
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

local types = stp.GetPersistedTable("stp.debug.Types", {})

function stp.RegisterType(name, tbl)
    assert(isstring(name), "'name' is not a string")
    assert(istable(tbl), "'tbl' is not a table")

    local checker = tbl.IsInstance
    assert(isfunction(checker), "'tbl.IsInstance' is not a function")

    types[name] = checker
end

function stp.CheckType(val, valname, allowed_types)
    if isstring(allowed_types) then allowed_types = {allowed_types} end

    if stp.IsAnyType(val, allowed_types) then
        return val
    end

    error(ConcatToString({
        "'",valname,"' is not a ",table.concat(allowed_types, "|"),",\n",
        "it is a [",type(val),"] ",stp.ToString(val, true)
    }), 2)
end

function stp.IsType(val, type)
    local checker = types[type]
    if checker == nil then 
        stp.Error("Non-registered type '",ty,"'")
    end

    return checker(val)
end

function stp.IsAnyType(val, intypes)
    for _, ty in ipairs(intypes) do
        local checker = types[ty]
        if checker == nil then 
            stp.Error("Non-registered type '",ty,"'")
        end

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

do
    local CV_DebugTypeSystem = CreateConVar("stplib_debug_typesys", 0)
    local CV_DebugDumpTypes = CreateConVar("stplib_debug_dumptypes", 0)
    local CV_Developer = GetConVar("developer")
    local Vars = {CV_DebugTypeSystem, CV_DebugDumpTypes, CV_Developer}

    local function UpdateDebugFlags()
        stp.DebugFlags = {
            TypeSystem = CV_DebugTypeSystem:GetBool() or CV_Developer:GetInt() >= 1,
            DumpTypes = CV_DebugDumpTypes:GetBool()
        }
    end
    UpdateDebugFlags()

    for _, var in ipairs(Vars) do
        cvars.AddChangeCallback(var:GetName(), UpdateDebugFlags, "stp.lib.DebugFlags")
    end
end