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

function LIB.BeginObject(typename)
    if stp.DebugFlags.TypeSystem then
        print("stp.obj.BeginObject", typename)
    end

    local meta = Metas[typename] or {}

    meta.__index = meta
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
        print("stp.obj.BeginExistingObject", meta)
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
        print("stp.obj.BeginTrait", typename)
    end

    local meta = Traits[typename] or {}
    meta.__index = meta
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
    if stp.DebugFlags.TypeSystem then
        print("stp.obj.Register", meta)
    end

    local typename = meta.TypeName
    assert(typename ~= nil)

    if meta.IsTrait then
       assert(rawget(meta,"__index") == meta, "Modifying `__index` of metatable breaks stp.trait.Apply!")
    end

    if meta.IsFullyRegistered ~= false then 
        stp.Error("Attempt to double-register object/trait ",typename)
    else
        meta.IsFullyRegistered = true
    end
    
    Traits[typename] = meta
    LIB._MergablesMerge(meta)

    hook.Run("stp.obj.OnMetaRegistered", meta)
end