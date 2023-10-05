local LIB = stp.obj

local Mergers = stp.GetPersistedTable("stp.obj.mergables.Mergers", {})

function LIB.MergerRegister(name, fn)
    if stp.DebugFlags.TypeSystem then
        print("stp.obj.MergerRegister", name, fn)
    end

    Mergers[name] = fn
end

function LIB.MergerRegisterArray(name, fn)
    LIB.MergerRegister(name, function(meta, k, desc)
        local array = {}
        for itemk, itemdesc in pairs(desc.List) do
            array[itemdesc.Idx] = { Key = itemk, Value = itemdesc.Value }
        end

        fn(meta, k, array)
    end)
end

function LIB._MergablesInit()
    return {}
end

local function GetInitMrgDesc(meta, key, merger_name)
    local mrg = meta.___mergables[key] or { MaxIdx = 0, MergerName = merger_name, List = {} }
    meta.___mergables[key] = mrg

    assert(mrg.MergerName == merger_name) -- TODO: error message: consistency check

    return mrg
end

function LIB.MergablesDeclare(meta, keyname, merger_name)
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

function LIB.MergablesAdd(meta, keyname, impl_name, merger_name, value)
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

function LIB.ApplyTrait(traitmeta, targetmeta)
    local debug_typesys = stp.DebugFlags.TypeSystem

    if debug_typesys then
        MsgN("stp.obj.ApplyTrait ", traitmeta, " to ", targetmeta)
    end

    if not traitmeta.IsTrait or not traitmeta.IsFullyRegistered then
        stp.Error("Attempt to apply not a registered trait ",traitmeta," to object")
    end
    assert(targetmeta.IsTrait ~= nil, "Attempt to apply to a non-stp_libcore object")
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

function LIB._MergablesMerge(meta)
    local debug_typesys = stp.DebugFlags.TypeSystem
    if debug_typesys then MsgN("stp.obj._MergablesMerge ",meta) end

    for k, desc in pairs(meta.___mergables) do
        local merger = desc.MergerName
        if debug_typesys then MsgN("> ",k," merger[",merger,"]") end

        Mergers[merger](meta, k, desc)
    end
end