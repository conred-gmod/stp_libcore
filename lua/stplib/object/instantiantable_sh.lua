local check_ty = STPLib.CheckType

local LIB = STPLib.Obj

function LIB.Create(typename, arg)
    check_ty(typename, "typename", "string")

    local meta = LIB.GetMeta(typename)
    if meta == nil then
        STPLib.Error("Attempt to create instance of unregistered type '", typename, "'")
    end

    if not isfunction(meta.Initialize) then
        STPLib.Error("Attempt to create instance of type '",typename,"' without function Initialize in metatable")
    end

    hook.Run("STPLib.Obj.OnPreCreate", typename, arg)

    local obj = setmetatable({}, {__index = meta})
    hook.Run("STPLib.Obj._InternalCreate", obj, arg)

    obj:Initialize(arg)
    hook.Run("STPLib.Obj.OnPostCreate", obj)

    return obj
end