local LIB = stp.obj

local Metas = stp.GetPersistedTable("stp.obj.registries.Metas", {})
local Traits = stp.GetPersistedTable("stp.obj.registries.Traits", {})

local function ObjectToString(self)
    return "[stp_libcore Object '"..self.TypeName.."']"
end

local function TraitToString(self)
    return "[stp_libcore Trait '"..self.TypeName.."']"
end

function LIB.GetObjectMetatables()
    return Metas
end

function LIB.GetTraitMetatables()
    return Traits
end

local function MakeIndex(meta)
    meta.__index = function(_, k)
        return rawget(meta, k)
    end
end

function LIB.BeginObject(typename)
    if stp.DebugFlags.TypeSystem then
        print("\nstp.obj.BeginObject", typename)
    end

    local meta = Metas[typename] or {}
    MakeIndex(meta)
    meta.__tostring = ObjectToString
    meta.___mergables = LIB._MergablesInit()
    meta.IsTrait = false
    setmetatable(meta, meta)

    meta.FinalMeta = meta
    meta.TypeName = typename
    meta.IsFullyRegistered = false
    hook.Run("stp.obj._OnMetaCreated", meta)

    return meta
end

function LIB.BeginExistingObject(meta)
    if stp.DebugFlags.TypeSystem then
        print("\nstp.obj.BeginExistingObject", meta)
    end

    local typename = meta.TypeName
    assert(typename ~= nil, "You need to set .TypeName")

    local existing_meta = Metas[typename]
    if existing_meta ~= nil and existing_meta ~= meta then
        ErrorNoHaltWithStack("Warning: overwriting existing metatable ",existing_meta," with ",meta," ",
            "for type '",typename,"'")
    end

    meta.___mergables = LIB._MergablesInit()
    meta.FinalMeta = meta
    meta.IsTrait = false
    meta.IsFullyRegistered = false
    hook.Run("stp.obj._OnMetaCreated", meta)

    return meta
end

function LIB.BeginTrait(typename)
    if stp.DebugFlags.TypeSystem then
        print("\nstp.obj.BeginTrait", typename)
    end

    local meta = Traits[typename] or {}
    MakeIndex(meta)
    meta.__call = LIB.ApplyTrait
    meta.__tostring = TraitToString
    meta.___mergables = LIB._MergablesInit()
    meta.IsTrait = true
    setmetatable(meta, meta)

    meta.TypeName = typename
    meta.IsFullyRegistered = false
    hook.Run("stp.obj._OnMetaCreated", meta)

    return meta
end

function LIB.Register(meta)
    local typename = meta.TypeName
    assert(typename ~= nil)

    if stp.DebugFlags.TypeSystem then
        print("stp.obj.Register", meta)
    end
    if stp.DebugFlags.DumpTypes then
        print("!stp.obj.Register ",meta," = >>>")
        PrintTable(meta, 1)
        print("<<<")
    end
    if stp.DebugFlags.TypeSystem or stp.DebugFlags.DumpTypes then print() end

    if meta.IsFullyRegistered ~= false then 
        stp.Error("Attempt to double-register object/trait ",typename)
    else
        meta.IsFullyRegistered = true
    end
    
    if meta.IsTrait then
        Traits[typename] = meta
    else
        Metas[typename] = meta
    end
    LIB._MergablesMerge(meta)

    hook.Run("stp.obj.OnMetaRegistered", meta)
end