local libobj = stp.obj
local PREFIX = "stp.obj.mergables."

local Mergers = stp.GetPersistedTable("stp.obj.mergables.Mergers", {})

function libobj.MergerRegister(name, fn)
    if stp.DebugFlags.TypeSystem then
        print("stp.obj.MergerRegister", name, fn)
    end

    Mergers[name] = fn
end

function libobj.MergerRegisterArray(name, fn)
    libobj.MergerRegister(name, function(meta, k, desc)
        local array = {}
        for itemk, itemdesc in pairs(desc.List) do
            array[itemdesc.Idx] = { Key = itemk, Value = itemdesc.Value }
        end

        fn(meta, k, array)
    end)
end

function libobj._MergablesInit()
    return {}
end

local function GetInitMrgDesc(meta, key, merger_name)
    local mrg = meta.___mergables[key] or { MaxIdx = 0, MergerName = merger_name, List = {} }
    meta.___mergables[key] = mrg

    assert(mrg.MergerName == merger_name) -- TODO: error message: consistency check

    return mrg
end

function libobj.MergablesDeclare(meta, keyname, merger_name)
    if stp.DebugFlags.TypeSystem then
        MsgN("stp.obj.MergablesDeclare\t", meta, ".", keyname,":[",merger_name,"]")
    end

    if meta.IsFullyRegistered then 
        stp.Error("Attempt to declare a mergable '",keyname,"' ",
            "in an already-registered object '",meta.TypeName,"'")
    end

    assert(Mergers[merger_name] ~= nil, "Attempt to use undefined merger '"..merger_name.."'")

    GetInitMrgDesc(meta, keyname, merger_name)
end

function libobj.MergablesAdd(meta, keyname, impl_name, merger_name, value)
    if stp.DebugFlags.TypeSystem then
        MsgN("stp.obj.MergablesDeclare\t", meta, ".", keyname,":[",merger_name,"]",
            "=\t[",impl_name,"]\t",value)
    end

    if meta.IsFullyRegistered then 
        stp.Error("Attempt to add a mergable '",keyname,":",impl_name,"' ",
            "to an already-registered object '",meta.TypeName,"'")
    end

    assert(Mergers[merger_name] ~= nil, "Attempt to use undefined merger '"..merger_name.."'")

    local mrg = GetInitMrgDesc(meta, keyname, merger_name)
    local mrglist = mrg.List

    if mrglist[impl_name] == nil then
        local idx = mrg.MaxIdx + 1
        mrg.MaxIdx = idx
        
        mrglist[impl_name] = { Idx = idx, Value = value }
    else
        mrglist[impl_name].Value = value
    end
end

local APPLY_SPECIAL_FIELDS = {
    -- Ignore all that
    ["__index"] = true,
    ["__tostring"] = true,
    ["__call"] = true,
    ["TypeName"] = true,
    ["IsTrait"] = true,
    ["IsFullyRegistered"] = true,

    -- Merge that
    ["___mergables"] = true,
}

function libobj.ApplyTrait(traitmeta, targetmeta)
    local debug_typesys = stp.DebugFlags.TypeSystem

    if debug_typesys then
        MsgN("stp.obj.ApplyTrait ", traitmeta, " to ", targetmeta)
    end

    if not traitmeta.IsTrait or not traitmeta.IsFullyRegistered then
        stp.Error("Attempt to apply not a registered trait ",traitmeta," to object")
    end
    assert(targetmeta.IsTrait ~= nil, "Attempt to apply to a non-stp_libobjcore object")
    assert(not targetmeta.IsFullyRegistered, "Attempt to apply to a fully-registered object")

    for k, v in pairs(traitmeta) do
        if APPLY_SPECIAL_FIELDS[k] then continue end

        targetmeta[k] = traitmeta[k]
    end

    local trait_mergables = traitmeta.___mergables
    local target_mergables = targetmeta.___mergables

    for k, mrgdesc in pairs(trait_mergables) do
        local targetdesc = target_mergables[k]
        local mergername = mrgdesc.MergerName

        if debug_typesys then
            MsgN("> mergable\t", k, "\tsource[",mergername,"]",
                " target[",(targetdesc and targetdesc.MergerName), "]")
        end

        if targetdesc == nil then
            local items = {}

            for key, mrgitem in SortedPairsByMemberValue(mrgdesc.List, "Idx") do
                local idx = mrgitem.Idx
                local value = mrgitem.Value

                if debug_typesys then
                    MsgN(">> ",key,"[",idx,"] copy ", value)
                end
                
                items[key] = {Idx = idx, Value = value}
            end

            targetdesc = {
                MaxIdx = mrgdesc.MaxIdx,
                MergerName = mergername,
                List = items
            }
            target_mergables[k] = targetdesc
            
            goto next_mergable
        end

        if targetdesc.MergerName ~= mergername then
            stp.Error("Error applying ",traitmeta," to ",targetmeta," ",
                ": mergable '",k,"': mergers are different:",
                " trait '",mergername,"' dest '",targetdesc.MergerName,"'")
        end

        for key, mrgitem in SortedPairsByMemberValue(mrgdesc.List, "Idx") do
            local value = mrgitem.Value
            local keydesc = targetdesc.List[key]
            if keydesc ~= nil then
                if debug_typesys then
                    MsgN(">> ",key,"[",keydesc.Idx,"] replace ", keydesc.Value, " with " ,value)
                end
                keydesc.Value = value 
            else
                local idx = targetdesc.MaxIdx + 1
                targetdesc.MaxIdx = idx
                
                if debug_typesys then
                    MsgN(">> ",key,"[",idx,"] new ", value)
                end
                targetdesc.List[key] = {
                    Idx = idx,
                    Value = value
                }
            end    
        end


        ::next_mergable::
        if debug_typesys then
            MsgN(">> maxidx[",targetdesc.MaxIdx,"] <<")
        end
    end
end

function libobj._MergablesMerge(meta)
    local debug_typesys = stp.DebugFlags.TypeSystem
    if debug_typesys then MsgN("stp.obj._MergablesMerge ",meta) end

    for k, desc in pairs(meta.___mergables) do
        local merger = desc.MergerName
        if debug_typesys then MsgN("> ",k," merger[",merger,"]") end

        Mergers[merger](meta, k, desc)
    end
end

do --Testing
    local PREFIX_TEST = PREFIX.."test."
    local RegTest = stp.testing.RegisterTest
    local RegTestFailing = stp.testing.RegisterTestFailing

    local MERGABLE_NAME = PREFIX_TEST.."Mergable"
    local function DefineSimpleMerger()
        libobj.RegisterMerger(MERGABLE_NAME, function(meta, key, desc)
            local parts = {}
            for impl, impldesc in SortedPairsByMemberValue(desc, "Idx") do
                table.insert(parts, impl.."="..tostring(impldesc.Value))
            end

            meta[key] = table.concat(parts)
        end)
    end
    
    local function AddSimpleMergable(meta, key, implname, value)
        libobj.MergablesAdd(meta, key, implname, MERGABLE_NAME, value)
    end

    local function DeclareSimpleMergable(meta, key)
        libobj.MergablesDeclare(meta, key, MERGABLE_NAME)
    end

    RegTest(PREFIX.."Declare", function()
        local ty = libobj.BeginObject(PREFIX_TEST.."Declare")
        DeclareSimpleMergable(ty, "Keyname")
        libobj.Register(ty)

        assert(istable(ty.Keyname))
        assert(table.IsEmpty(ty.Keyname))
    end)

    RegTestFailing(PREFIX.."DeclareUndefinedMerger", function()
        local ty = libobj.BeginObject(PREFIX_TEST.."DeclareUndefinedMerger")
        libobj.MergablesDeclare(ty, "Keyname", PREFIX_TEST.."NoSuchMergerExists")
        libobj.Register(ty)
    end)

    RegTest(PREFIX.."SimpleUse", function()
        DefineSimpleMerger()

        local ty = libobj.BeginObject(PREFIX_TEST.."SimpleUse")
        
        AddSimpleMergable(ty, "First", "Impl1", 10)
        AddSimpleMergable(ty, "Second", "Impl1", 10)
        
        AddSimpleMergable(ty, "First", "Impl2", 15) -- Add another implementation to mergable
        AddSimpleMergable(ty, "Second", "Impl1", -10) -- Overwrite implementation of mergable

        libobj.Register(ty)
        
        assert(ty.First[1] == "Impl1=10")
        assert(ty.First[2] == "Impl2=15")

        assert(#ty.Second == 1, "Overwriting not worked correctly, it created extra elements")
        assert(ty.Second[1] == "Impl1=-10", "Value was not overwritten correctly")
    end)

    RegTest(PREFIX.."SimpleInheritance", function()
        DefineSimpleMerger()

        local tbase = libobj.BeginTrait(PREFIX_TEST.."SimpleInheritance.Base")
        AddSimpleMergable(tbase, "Combined", "Base",4)
        AddSimpleMergable(tbase, "Overwritten", "OnlyValue", 99)
        libobj.Register(tbase)

        local tfinal = libobj.BeginObject(PREFIX_TEST.."SimpleInheritance.Final")
        AddSimpleMergable(tfinal, "Combined", "First", 0)
        tbase(tfinal)
        AddSimpleMergable(tfinal, "Combined", "Final", 8)
        AddSimpleMergable(tfinal, "Overwritten", "OnlyValue", 110)
        libobj.Register(tfinal)

        assert(tfinal.Combined[1] == "First=0")
        assert(tfinal.Combined[2] == "Base=4")
        assert(tfinal.Combined[3] == "Final=8")

        assert(#tfinal.Overwritten == 1)
        assert(tfinal.Overwritten[1] == "OnlyValue=110")
    end)

    RegTest(PREFIX.."DiamondInheritance", function()
        DefineSimpleMerger()

        local ta = libobj.BeginTrait(PREFIX_TEST.."DiamondInheritance.A")
        AddSimpleMergable(ta, "Keyname", "A", 4)
        libobj.Register(ta)

        local tb1 = libobj.BeginTrait(PREFIX_TEST.."DiamondInheritance.B1")
        ta(tb1)
        AddSimpleMergable(tb1, "Keyname", "B1", 8)
        libobj.Register(tb1)

        assert(#tb1.Keyname == 2)
        assert(tb1.Keyname[1] == "A=4")
        assert(tb1.Keyname[2] == "B1=8")

        local tb2 = libobj.BeginTrait(PREFIX_TEST.."DiamondInheritance.B2")
        ta(tb2)
        AddSimpleMergable(tb2, "Keyname", "B2", 15)
        libobj.Register(tb2)

        assert(#tb2.Keyname == 2)
        assert(tb2.Keyname[1] == "A=4")
        assert(tb2.Keyname[2] == "B2=15")

        local tfinal = libobj.BeginObject(PREFIX_TEST.."DiamondInheritance.Final")
        tb1(tfinal)
        tb2(tfinal)
        AddSimpleMergable(tb2, "Keyname", "Final", 16)
        libobj.Register(tfinal)

        assert(#tfinal.Keyname == 4)
        assert(tfinal.Keyname[1] == "A=4")
        assert(tfinal.Keyname[2] == "B1=8")
        assert(tfinal.Keyname[3] == "B2=15")
        assert(tfinal.Keyname[4] == "Final=16")
    end)
end