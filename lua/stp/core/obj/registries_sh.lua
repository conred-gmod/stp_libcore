local libobj = stp.obj

local PREFIX = "stp.obj.registries."

local Metas = stp.GetPersistedTable(PREFIX.."Metas", {})
local Traits = stp.GetPersistedTable(PREFIX.."Traits", {})

local function ObjectToString(self)
    return "[stp_libcore Object '"..self.TypeName.."']"
end

local function TraitToString(self)
    return "[stp_libcore Trait '"..self.TypeName.."']"
end

function libobj.GetObjectMetatables()
    return Metas
end

function libobj.GetTraitMetatables()
    return Traits
end

local function MakeIndex(meta)
    meta.__index = function(_, k)
        return rawget(meta, k)
    end
end

function libobj.BeginObject(typename)
    if stp.DebugFlags.TypeSystem then
        print("\nstp.obj.BeginObject", typename)
    end

    local meta = Metas[typename] or {}
    MakeIndex(meta)
    meta.__tostring = ObjectToString
    meta.___mergables = libobj._MergablesInit()
    meta.IsTrait = false
    setmetatable(meta, meta)

    meta.FinalMeta = meta
    meta.TypeName = typename
    meta.IsFullyRegistered = false
    hook.Run("stp.obj._OnMetaCreated", meta)

    return meta
end

function libobj.BeginExistingObject(meta)
    if stp.DebugFlags.TypeSystem then
        print("\nstp.obj.BeginExistingObject", meta)
    end

    local typename = meta.TypeName
    assert(typename ~= nil, "You need to set .TypeName")
    assert(meta.IsTrait ~= true, "You can't modify existing traits, only final objects")

    local existing_meta = Metas[typename]
    if existing_meta ~= nil and existing_meta ~= meta then
        ErrorNoHaltWithStack("Warning: overwriting existing metatable ",existing_meta," with ",meta," ",
            "for type '",typename,"'")
    end

    meta.___mergables = libobj._MergablesInit()
    meta.FinalMeta = meta
    meta.IsTrait = false
    meta.IsFullyRegistered = false
    hook.Run("stp.obj._OnMetaCreated", meta)

    return meta
end

function libobj.BeginTrait(typename)
    if stp.DebugFlags.TypeSystem then
        print("\nstp.obj.BeginTrait", typename)
    end

    local meta = Traits[typename] or {}
    MakeIndex(meta)
    meta.__call = libobj.ApplyTrait
    meta.__tostring = TraitToString
    meta.___mergables = libobj._MergablesInit()
    meta.IsTrait = true
    setmetatable(meta, meta)

    meta.TypeName = typename
    meta.IsFullyRegistered = false
    hook.Run("stp.obj._OnMetaCreated", meta)

    return meta
end

function libobj.Register(meta)
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
    libobj._MergablesMerge(meta)

    hook.Run("stp.obj.OnMetaRegistered", meta)
end

do -- Tests
    local PREFIX_TEST = PREFIX.."test."
    local RegTest = stp.testing.RegisterTest
    local RegTestFailing = stp.testing.RegisterTestFailing

    RegTest(PREFIX.."ObjectRegistration",function()
        local TYPE = PREFIX_TEST.."ObjectRegistration"

        local meta = libobj.BeginObject(TYPE)
        meta.TheNumber = 42

        assert(not meta.IsTrait)
        assert(not meta.IsFullyRegistered)
        assert(meta.TheNumber == 42)

        libobj.Register(meta)
        
        assert(meta.IsFullyRegistered)
        assert(libobj.GetObjectMetatables()[TYPE] == meta)
        assert(libobj.GetTraitMetatables()[TYPE] == nil)
    end)

    RegTest(PREFIX.."TraitRegistrationAndImplementation",function()
        -- Definition of the trait
        local TYPE_TRAIT = PREFIX_TEST.."TraitRegistration"
        local traitmeta = libobj.BeginTrait(TYPE_TRAIT)

        traitmeta.TheNumber = 42
        traitmeta.TheDupe = 23

        assert(traitmeta.IsTrait)
        assert(not traitmeta.IsFullyRegistered)
        assert(traitmeta.TheNumber == 42)
        assert(traitmeta.TheDupe == 23)

        libobj.Register(traitmeta)
        
        assert(traitmeta.IsFullyRegistered)
        assert(libobj.GetTraitMetatables()[TYPE_TRAIT] == traitmeta)
        assert(libobj.GetObjectMetatables()[TYPE_TRAIT] == nil)

        -- Definition of the object
        local TYPE_OBJ = PREFIX_TEST.."TraitRegistrationObject"
        local objmeta = libobj.BeginObject(TYPE_OBJ)
        
        traitmeta(objmeta)
        objmeta.TheDupe = 108

        libobj.Register(objmeta)

        -- Inheritance check
        assert(objmeta.TheNumber == 42)
        assert(objmeta.TheDupe == 108)
    end)

    RegTestFailing(PREFIX.."DoubleRegistration", function()
        local meta = libobj.BeginObject(PREFIX_TEST.."DoubleRegistration")

        libobj.Register(meta)
        libobj.Register(meta)
    end)

    RegTestFailing(PREFIX.."UnregisteredTraitUsage", function()
        local trait = libobj.BeginTrait(PREFIX_TEST.."UnregisteredTrait")

        local object = libobj.BeginObject(PREFIX_TEST.."UnregisteredTraitObject")
        trait(object)
    end)

    RegTestFailing(PREFIX.."AddingTraitToRegisteredObject", function()
        local trait = libobj.BeginTrait(PREFIX_TEST.."AddingTraitToRegisteredObject.Trait")
        libobj.Register(trait)

        local object = libobj.BeginObject(PREFIX_TEST.."AddingTraitToRegisteredObject.Object")
        libobj.Register(object)

        trait(object)
    end)

    RegTest(PREFIX.."ObjectReregistration", function()
        local meta = libobj.BeginObject(PREFIX_TEST.."ObjectReregistration")
        meta.TheNumber = 42
        libobj.Register(meta)

        assert(meta.TheNumber == 42)

        local samemeta = libobj.BeginExistingObject(meta)
        samemeta.TheNumber = 108
        libobj.Register(samemeta)

        assert(meta == samemeta)
        assert(meta.TheNumber == 108)
    end)

    RegTestFailing(PREFIX.."ObjectReregistrationOnTrait", function()
        local meta = libobj.BeginTrait(PREFIX_TEST.."ObjectReregistrationOnTrait")
        libobj.Register(meta)

        libobj.BeginExistingObject(meta) -- Fails
    end)
end
