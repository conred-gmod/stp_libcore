local sobj = stp.obj

local PREFIX = "stp.obj.registries."

local Metas = stp.GetPersistedTable(PREFIX.."Metas", {})
local Traits = stp.GetPersistedTable(PREFIX.."Traits", {})

local function ObjectToString(self)
    return "[stp_libcore Object '"..self.TypeName.."']"
end

local function TraitToString(self)
    return "[stp_libcore Trait '"..self.TypeName.."']"
end

function sobj.GetObjectMetatables()
    return Metas
end

function sobj.GetTraitMetatables()
    return Traits
end

local function MakeIndex(meta)
    meta.__index = function(_, k)
        return rawget(meta, k)
    end
end

function sobj.BeginObject(typename)
    if stp.DebugFlags.TypeSystem then
        print("\nstp.obj.BeginObject", typename)
    end

    local meta = Metas[typename] or {}
    MakeIndex(meta)
    meta.__tostring = ObjectToString
    meta.___mergables = sobj._MergablesInit()
    meta.IsTrait = false
    setmetatable(meta, meta)

    meta.FinalMeta = meta
    meta.TypeName = typename
    meta.IsFullyRegistered = false
    hook.Run("stp.obj._OnMetaCreated", meta)

    return meta
end

function sobj.BeginExistingObject(meta)
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

    meta.___mergables = sobj._MergablesInit()
    meta.FinalMeta = meta
    meta.IsTrait = false
    meta.IsFullyRegistered = false
    hook.Run("stp.obj._OnMetaCreated", meta)

    return meta
end

function sobj.BeginTrait(typename)
    if stp.DebugFlags.TypeSystem then
        print("\nstp.obj.BeginTrait", typename)
    end

    local meta = Traits[typename] or {}
    MakeIndex(meta)
    meta.__call = sobj.ApplyTrait
    meta.__tostring = TraitToString
    meta.___mergables = sobj._MergablesInit()
    meta.IsTrait = true
    setmetatable(meta, meta)

    meta.TypeName = typename
    meta.IsFullyRegistered = false
    hook.Run("stp.obj._OnMetaCreated", meta)

    return meta
end

function sobj.Register(meta)
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
    sobj._MergablesMerge(meta)

    hook.Run("stp.obj.OnMetaRegistered", meta)

    return meta
end

do -- Tests
    local PREFIX_TEST = PREFIX.."test."
    local RegTest = stp.testing.RegisterTest
    local RegTestFailing = stp.testing.RegisterTestFailing

    RegTest(PREFIX.."ObjectRegistration",function()
        local TYPE = PREFIX_TEST.."ObjectRegistration"

        local meta = sobj.BeginObject(TYPE)
        meta.TheNumber = 42

        assert(not meta.IsTrait)
        assert(not meta.IsFullyRegistered)
        assert(meta.TheNumber == 42)

        sobj.Register(meta)
        
        assert(meta.IsFullyRegistered)
        assert(sobj.GetObjectMetatables()[TYPE] == meta)
        assert(sobj.GetTraitMetatables()[TYPE] == nil)
    end)

    RegTest(PREFIX.."TraitRegistrationAndImplementation",function()
        -- Definition of the trait
        local TYPE_TRAIT = PREFIX_TEST.."TraitRegistration"
        local traitmeta = sobj.BeginTrait(TYPE_TRAIT)

        traitmeta.TheNumber = 42
        traitmeta.TheDupe = 23

        assert(traitmeta.IsTrait)
        assert(not traitmeta.IsFullyRegistered)
        assert(traitmeta.TheNumber == 42)
        assert(traitmeta.TheDupe == 23)

        sobj.Register(traitmeta)
        
        assert(traitmeta.IsFullyRegistered)
        assert(sobj.GetTraitMetatables()[TYPE_TRAIT] == traitmeta)
        assert(sobj.GetObjectMetatables()[TYPE_TRAIT] == nil)

        -- Definition of the object
        local TYPE_OBJ = PREFIX_TEST.."TraitRegistrationObject"
        local objmeta = sobj.BeginObject(TYPE_OBJ)
        
        traitmeta(objmeta)
        objmeta.TheDupe = 108

        sobj.Register(objmeta)

        -- Inheritance check
        assert(objmeta.TheNumber == 42)
        assert(objmeta.TheDupe == 108)
    end)

    RegTestFailing(PREFIX.."DoubleRegistration", function()
        local meta = sobj.BeginObject(PREFIX_TEST.."DoubleRegistration")

        sobj.Register(meta)
        sobj.Register(meta)
    end)

    RegTestFailing(PREFIX.."UnregisteredTraitUsage", function()
        local trait = sobj.BeginTrait(PREFIX_TEST.."UnregisteredTrait")

        local object = sobj.BeginObject(PREFIX_TEST.."UnregisteredTraitObject")
        trait(object)
    end)

    RegTestFailing(PREFIX.."AddingTraitToRegisteredObject", function()
        local trait = sobj.BeginTrait(PREFIX_TEST.."AddingTraitToRegisteredObject.Trait")
        sobj.Register(trait)

        local object = sobj.BeginObject(PREFIX_TEST.."AddingTraitToRegisteredObject.Object")
        sobj.Register(object)

        trait(object)
    end)

    RegTest(PREFIX.."ObjectReregistration", function()
        local meta = sobj.BeginObject(PREFIX_TEST.."ObjectReregistration")
        meta.TheNumber = 42
        sobj.Register(meta)

        assert(meta.TheNumber == 42)

        local samemeta = sobj.BeginExistingObject(meta)
        samemeta.TheNumber = 108
        sobj.Register(samemeta)

        assert(meta == samemeta)
        assert(meta.TheNumber == 108)
    end)

    RegTestFailing(PREFIX.."ObjectReregistrationOnTrait", function()
        local meta = sobj.BeginTrait(PREFIX_TEST.."ObjectReregistrationOnTrait")
        sobj.Register(meta)

        sobj.BeginExistingObject(meta) -- Fails
    end)

    RegTest(PREFIX.."MultipleInheritance", function()
        local trBase = sobj.BeginTrait(PREFIX_TEST.."MultipleInheritance.TraitBase")
        tr1.BaseValue = 108
        sobj.Register(trBase)


        local tr1 = sobj.BeginTrait(PREFIX_TEST.."MultipleInheritance.Trait1")
        trBase(tr1)
        tr1.Value1 = 4
        sobj.Register(tr1)

        local tr2 = sobj.BeginTrait(PREFIX_TEST.."MultipleInheritance.Trait2")
        trBase(tr1)
        tr2.Value2 = 8
        sobj.Register(tr2)

        local obj = sobj.BeginObj(PREFIX_TEST.."MultipleInheritance.Object")
        tr1(obj)
        tr2(obj)
        sobj.Register(obj)

        assert(obj.BaseValue == 108)
        assert(obj.Value1 == 4)
        assert(obj.Value2 == 8)
    end)

    -- https://github.com/conred-gmod/stp_libcore/issues/2
    RegTest(PREFIX.."NoRepeatedTraitApplication", function()
        local trait = sobj.BeginTrait(PREFIX_TEST.."NoRepeatedTraitApplication.Trait")
        trait.Value = 108
        sobj.Register(trait)

        local obj = sobj.BeginObject(PREFIX_TEST.."NoRepeatedTraitApplication.Object")
        trait(obj)
        obj.Value = 23
        trait(obj) -- Trait should not be re-applied here
        sobj.Register(obj)

        assert(obj.Value == 23)
    end)
end
