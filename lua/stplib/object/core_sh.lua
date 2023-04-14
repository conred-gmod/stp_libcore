local check_ty = STPLib.CheckType

local LIB = LIB or {}
STPLib.Obj = LIB

local Metas = Metas or {}

function Obj.Register(meta)
    check_ty(meta, "meta", "table")
    local typename = check_ty(meta.Type, "meta.Type", "string")

    hook.Run("STPLib.Obj._InternalRegister", meta)

    Metas[typename] = meta
end

function Obj.GetMeta(typename)
    return Metas[typename]
end