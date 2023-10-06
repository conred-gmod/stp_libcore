local libo = stp.obj

function libo.ApplyMany(target, ...)
    for i = 1, select("#", ...) do
        local fn = select(i, ...)

        if fn ~= false then
            fn(target)
        end
    end

    return target
end

function libo.ConstructNestedType(owner, postfix, ...)
    local typename = owner.TypeName.."."..postfix

    local META = libo.BeginObject(typename)
    META.PostfixName = postfix
    META.OwnerType = owner

    libo.ApplyMany(META, ...)

    libo.Register(META)
    return META
end

libo.MergerRegisterArray("CallInOrder_Member", function(meta, key, values)
    local fns = {} -- Hope this will get inlined
    for i, pair in ipairs(values) do
        fns[i] = pair.Value
    end

    meta[key] = function(self, ...)
        for _, fn in ipairs(fns) do
            fn(self, ...)
        end
    end
end)

function libo.HookDefine(meta, keyname)
    libo.MergablesDeclare(meta, keyname, "CallInOrder_Member")
end

function libo.HookAdd(meta, keyname, valname, fn)
    libo.MergablesAdd(meta, keyname, valname, "CallInOrder_Member", fn)
end


function libo.CheckNotFullyRegistered(meta)
    if meta.IsFullyRegistered == nil or meta.IsTrait == nil then
        stp.Error("Passed non-trait/object '",meta,"'")
    elseif meta.IsFullyRegistered then
        stp.Error("Passed fully-registered ",meta)
    end
end

function libo.CheckFullyRegistered(meta)
    if meta.IsFullyRegistered == nil or meta.IsTrait == nil then
        stp.Error("Passed non-trait/object '",meta,"'")
    elseif not meta.IsFullyRegistered then
        stp.Error("Passed non-fully-registered ",meta)
    end
end


do
    local MRG = "stp.obj.util.AbstractField"
    local MRG_FIELD = "__abstract_fields"

    libo.MergerRegisterArray(MRG, function(meta, mrg_field, abstracts)
        assert(mrg_field == MRG_FIELD)
        if meta.IsTrait then return end

        for _, pair in ipairs(abstracts) do
            local key = pair.Key
            local val = meta[key]
            local tys = pair.Value

            if not stp.IsAnyType(val, tys) then
                stp.Error(meta,": abstract field '",key,"' has invalid type '",type(val),"',",
                    " not '",table.concat(tys,"|"),"'")
            end
        end
    end)
    
    function libo.MarkAbstract(meta, keyname, valtype)
        if isstring(valtype) then valtype = { valtype } end

        libo.MergablesAdd(meta, MRG_FIELD, keyname, MRG, valtype)
    end
end