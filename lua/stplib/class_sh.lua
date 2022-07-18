local check_ty = STPLib.CheckType

local ClassMetas = ClassMetas or {}

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

    local meta = STPLib.GetClassMeta(name)

    local old_index = meta.__index
    local new_index

    if istable(old_index) then
        new_index = function(self, k)
            local parent_v = parent_index(self, k)
            if parent_v ~= nil then return parent_v end

            return old_index[k]
        end
    elseif isfunction(old_index) then
        new_index = function(self, k)
            local parent_v = parent_index(self, k)
            if parent_v ~= nil then return parent_v end

            return old_index(self, k)
        end
    else
        new_index = function(self, k)
            local parent_v = parent_index(self, k)
            if parent_v ~= nil then return parent_v end

            return meta[k]
        end
    end

    meta.__index = new_index

    local ctor = function(base)
        return setmetatable(base, meta)
    end

    --[[STPLib.RegisterType(name, { IsInstance = function(val)
        if not istable(val) then return false end

        return debug.getmetatable(val) == meta
    end})]]

    return meta, ctor
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