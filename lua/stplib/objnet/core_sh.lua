local check_ty = STPLib.CheckType

local LIB = LIB or {}
STPLib.ObjNet = LIB

local Tracker = Tracker or STPLib.Obj.CreateTracker("STPLib.ObjNet.Networkable")

local META = META or {}

function LIB.RegisterNetworkable(meta)
    hook.Run("STPLib.ObjNet._OnPreRegisterNetworkable", meta)

    table.Merge(meta, META)

    Tracker:RegisterType(meta)
end

function LIB.IsNetworkable(name)
    if istable(name) then
        return LIB.IsNetworkable(name.Type)
    end

    check_ty(name, "name", "string")

    return Tracker:IsTracked(type)
end

function META:Net_GetId()
    return Tracker:GetId(self)
end

function LIB.GetObjectById(id)
    return Tracker:GetObject(id)
end

if CLIENT then
    hook.Add("STPLib.Obj._InternalCreate", "Networkable_ClientCheck", function(obj, arg)
        if not Tracker:IsTracked(obj.Type) then return end

        if arg.___Networkable_ClientCreate ~= true then
            STPLib.Error("Attempt to manually create networkable object clientside: ",obj)
            -- Do not use _CreateObject if you are not a developer of this library.
            -- Objects should be created serverside and then transmitted.
        end
    end)

    function LIB._CreateObject(type, arg)
        assert(Tracker:IsTracked(type))
        arg.___Networkable_ClientCreate = true

        return STPLib.Obj.Create(type, arg)
    end
end

function Tracker:OnRegistered(obj)
    hook.Add("STPLib.ObjNet.OnRegistered", obj)
end

function Tracker:OnPreUnregistered(obj, cascaded)
    hook.Add("STPLib.ObjNet.OnPreUnergistered", obj, cascaded)
end