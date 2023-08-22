local libo = stp.obj

function libo.ApplyMany(target, ...)
    for _, fn in ipairs({...}) do
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
        fns = pair.Value
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
                    " not ",table.concat(tys,"|"))
            end
        end
    end)
    
    function libo.MarkAbstract(meta, keyname, valtype)
        if isstring(valtype) then valtype = { valtype } end

        libo.MergablesAdd(meta, MRG_FIELD, keyname, MRG, valtype)
    end
end


function libo.MakeAttached(accessor)
    return function(meta)
        local parentmeta = meta.OwnerType
        if parentmeta == nil then
            stp.Error(meta," is not a 'stp.obj.NestedObject'")
        end
    
        libo.CheckNotFullyRegistered(meta)
        libo.CheckNotFullyRegistered(parentmeta)
    
        local typename = meta.TypeName
        local keyname = "__attached_"..typename
    
        libo.HookDefine(meta, "FillInitParams")
    
        libo.HookAdd(parentmeta, "Init", "attach_"..typename, function(self, params)
            local attachparams = {}
            meta.FillInitParams(params, attachparams)
            attachparams.Owner = self
    
            local obj = meta.Create(attachparams)

    
            self[keyname] = obj
        end)

        libo.HookAdd(meta, "Init", "init_"..typename, function(self, params)
            self.Owner = params.Owner
        end)
    
        libo.HookAdd(parentmeta, "OnRemove", "remove_"..typename, function(self)
            local obj = self[keyname]
            assert(IsValid(obj), typename.." is not valid at owner remove time")
    
            obj:Remove(true) -- Cascaded?
    
            self[keyname] = nil 
        end)

        parentmeta[accessor] = function(self) 
            return self[keyname]
        end
    end
end