local LIB = stp.obj

local Mergers = stp.GetPersistedTable("stp.obj.mergables.Mergers", {})

function LIB.MergerRegister(name, fn)
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

function LIB.MergablesDeclare(meta, keyname, merger_name)
    if meta.IsFullyRegistered then 
        stp.Error("Attempt to declare a mergable '",keyname,"' ",
            "in an already-registered object '",meta.TypeName,"'")
    end

    assert(Mergers[merger_name] ~= nil, "Attempt to use undefined merger '"..merger_name.."'")

    local mrg = meta.___mergables[keyname] or { MaxIdx = 0, MergerName = merger_name, List = {} }
    meta.___mergables[keyname] = mrg

    assert(mrg.MergerName == merger_name) -- TODO: error message: consistency check
end

function LIB.MergablesAdd(meta, keyname, impl_name, merger_name, value)
    if meta.IsFullyRegistered then 
        stp.Error("Attempt to add a mergable '",keyname,":",impl_name,"' ",
            "to an already-registered object '",meta.TypeName,"'")
    end

    assert(Mergers[merger_name] ~= nil, "Attempt to use undefined merger '"..merger_name.."'")

    local mrg = meta.___mergables[keyname] or { MaxIdx = 0, MergerName = merger_name, List = {} }
    meta.___mergables[keyname] = mrg

    assert(mrg.MergerName == merger_name) -- TODO: error message: consistency check
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
    if stp.DebugFlags.TypeSystem then
        print("stp.obj.ApplyTrait", traitmeta, "to", targetmeta)
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
        if target_mergables[k] == nil then
            target_mergables[k] = mrgdesc
            continue
        end

        local targetdesc = target_mergables[k]
        if targetdesc.MergerName ~= mrgdesc.MergerName then
            stp.Error("Error applying ",traitmeta," to ",targetmeta," ",
                ": mergable '",k,"': mergers are different:",
                " trait '",mrgdesc.MergerName,"' dest '",targetdesc.MergerName,"'")
        end

        for key, mrgitem in SortedPairsByMemberValue(mrgdesc.List, "Idx") do
            if targetdesc[key] ~= nil then
                targetdesc[key].Value = mrgitem.Value
            else
                local idx = targetdesc.MaxIdx + 1
                targetdesc.MaxIdx = idx

                targetdesc[key] = {
                    Idx = idx,
                    Value = mrgitem.Value
                }
            end    
        end
    end
end

function LIB._MergablesMerge(meta)
    for k, desc in pairs(meta.___mergables) do
        local merger = desc.MergerName

        Mergers[merger](meta, k, desc)
    end
end