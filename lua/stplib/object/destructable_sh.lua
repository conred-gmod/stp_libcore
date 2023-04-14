local check_ty = STPLib.CheckType

local LIB = STPLib.Obj

hook.Add("STPLib.Obj._InternalRegister", "___Destructable", function(meta)
    function meta:IsValid()
        return self.___isValid or false
    end
end)

hook.Add("STPLib.Obj._InternalCreate", "___Destructable", function(obj)
    if obj.OnPreRemoved ~= nil then
        obj.___isValid = true
    end
end)

function LIB.Remove(obj, cascaded)
    check_ty(obj, "obj", "table")

    if obj.OnPreRemoved == nil then
        STPLib.Error("Attempt to remove object '",obj,"' that is not 'RemovableObject' ",
            "(has no OnPreRemoved hook function)")
    end

    if not obj:IsValid() then
        STPLib.Error("Attempt to (double-?)remove invalid object '",obj,"'")
    end

    hook.Run("STPLib.Obj.OnPreRemoved", obj, cascaded)
    obj:OnPreRemoved(cascaded)

    obj.___isValid = false

    hook.Run("STPLib.Obj.OnPostRemoved", obj, cascaded)
end