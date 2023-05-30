local LIB = stp.obj

function LIB.ApplyMany(target, ...)
    for _, fn in ipairs({...}) do
        if fn ~= false then
            fn(target)
        end
    end

    return target
end

LIB.MergerRegisterArray("CallInOrder_Member", function(meta, key, values)
    local fns = {} -- Hope this will get inlined
    for i, pair in ipairs(values) do
        fns = pair.Value
    end

    meta[key] = function(self, ...)
        for _, fn in ipairs(fns) do
            fn(self, ...)
        end
    end
end)

function LIB.HookDefine(meta, keyname)
    LIB.MergablesDeclare(meta, keyname, "CallInOrder_Member")
end

function LIB.HookAdd(meta, keyname, valname, fn)
    LIB.MergablesAdd(meta, keyname, valname, "CallInOrder_Member", fn)
end


function LIB.CheckNotFullyRegistered(meta)
    if meta.IsFullyRegistered == nil or meta.IsTrait == nil then
        stp.Error("Passed non-trait/object '",meta,"'")
    elseif meta.IsFullyRegistered then
        stp.Error("Passed fully-registered ",meta)
    end
end

function LIB.CheckFullyRegistered(meta)
    if meta.IsFullyRegistered == nil or meta.IsTrait == nil then
        stp.Error("Passed non-trait/object '",meta,"'")
    elseif not meta.IsFullyRegistered then
        stp.Error("Passed non-fully-registered ",meta)
    end
end


do
    local MRG = "stp.core.obj.util.AbstractField"
    local MRG_FIELD = "__abstract_fields"

    LIB.MergerRegisterArray(MRG, function(meta, mrg_field, abstracts)
        assert(mrg_field == MRG_FIELD)
        if meta.IsTrait then return end

        for _, pair in ipairs(abstracts) do
            local key = pair.Key
            local val = meta[key]
            local tys = pair.Value

            if not stp.IsAnyType(val, tys) then
                stp.Error(meta,": abstract field '",key,"' has invalid type '",type(val),"',",
                    " not ",table.concat(tys,"|"))
            end
        end
    end)
    
    function LIB.MarkAbstract(meta, keyname, valtype)
        if isstring(valtype) then valtype = { valtype } end

        LIB.MergablesAdd(meta, MRG_FIELD, keyname, valtype)
    end
end