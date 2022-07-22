local check_ty = STPLib.CheckType

local ClassMetas = ClassMetas or {}
local ClassMetasInv = ClassMetasInv or {}

function STPLib.DefineClass(name, parents)
    check_ty(name, "name", "string")
    check_ty(parents, "parents", "table")

    local parent_metas = {}
    for i, parent_name in ipairs(parents) do
        if parent_name == name then
            STPLib.Error("Attempt to add '",name,"' to parents of itself!")
        end

        local meta = ClassMetas[parent_name]
        if meta == nil then
            STPLib.Error("Class '",name,"' has undefined parent '",parent_name,"'")
        end

        parent_metas[i] = meta
    end

    local parent_index = function(self, k)
        for _, parent_meta in ipairs(parent_metas) do
            if parent_meta[k] ~= nil then
                return parent_meta[k]
            end
        end
    end


    STPLib.AddIndexBefore(name, parent_index)

    local meta = STPLib.GetClassMeta(name)

    local ctor = function(base)
        return setmetatable(base, meta)
    end

    ClassMetasInv[meta] = name

    --[[STPLib.RegisterType(name, { IsInstance = function(val)
        if not istable(val) then return false end

        return debug.getmetatable(val) == meta
    end})]]

    return meta, ctor, unpack(parent_metas)
end

function STPLib.GetClassMeta(name)
    check_ty(name, "name", "string")

    if ClassMetas[name] ~= nil then
        return ClassMetas[name]
    end

    local meta = {}
    meta.__index = meta

    ClassMetas[name] = meta
    return meta
end

function STPLib.GetClassName(obj)
    check_ty(obj, "obj", "table")

    local meta = debug.getmetatable(obj)

    if meta == nil then return nil end

    return ClassMetasInv[meta]
end

function STPLib.AddIndexBefore(name, index_fn)
    local meta = STPLib.GetClassMeta(name)
    local old_index = meta.__index

    local new_index

    if istable(old_index) then
        new_index = function(self, k)
            local parent_v = index_fn(self, k)
            if parent_v ~= nil then return parent_v end

            return old_index[k]
        end
    elseif isfunction(old_index) then
        new_index = function(self, k)
            local parent_v = index_fn(self, k)
            if parent_v ~= nil then return parent_v end

            return old_index(self, k)
        end
    else
        new_index = index_fn
    end

    meta.__index = new_index
end

function STPLib.AddIndexAfter(name, index_fn)
    local meta = STPLib.GetClassMeta(name)
    local old_index = meta.__index

    local new_index

    if istable(old_index) then
        new_index = function(self, k)
            if old_index[k] ~= nil then return old_index[k] end

            return index_fn(self, k)
        end
    elseif isfunction(old_index) then
        new_index = function(self, k)
            local val = old_index(self, k)
            if val ~= nil then return val end

            return index_fn(self, k)
        end
    else
        new_index = index_fn
    end

    meta.__index = new_index
end