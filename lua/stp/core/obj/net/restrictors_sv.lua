local librest = stp.obj.net.restrictors
local ObjTracker = stp.obj.Tracker

local Unrestricted = stp.GetPersistedTable("stp.obj.net.restrictors.Unrestricted", {})
local RestrictedByThis = stp.GetPersistedTable("stp.obj.net.restrictors.RestrictedByThis", {})

librest.Unrestricted = Unrestricted
librest.RestrictedByThis = RestrictedByThis

local function CheckRestrictorLoop(cur, added)
    while cur ~= nil do
        assert(cur ~= added, "Restrictor loop detected!")

        cur = cur:NetGetRestrictor()
    end
end

function librest._Set(obj, restrictor)
    local oldrestrictor = obj:NetGetRestrictor()
    CheckRestrictorLoop(restrictor, obj)

    if oldrestrictor == restrictor then return end

    if restrictor ~= nil then
        Unrestricted[obj] = nil
    else
        Unrestricted[obj] = true
    end

    if oldrestrictor then
        RestrictedByThis[oldrestrictor][obj] = nil
    end

    if restrictor then
        RestrictedByThis[restrictor] = RestrictedByThis[restrictor] or {}
        RestrictedByThis[restrictor][obj] = true
    end
end

hook.Add("stp.obj.Tracker.OnPreTracked", "stp.obj.net.Restrictors", function(obj, id)
    if not ObjTracker.IsNetworkable(id) then return end

    RestrictedByThis[obj] = RestrictedByThis[obj] or {}
    Unrestricted[obj] = true
end)

hook.Add("stp.obj.PreRemoved", "spt.obj.net.Restrictors", function(obj)
    if not ObjTracker.IsNetworkable(obj) then return end

    Unrestricted[obj] = nil
    RestrictedByThis[obj] = nil

    local restr = obj:NetGetRestrictor()
    if restr ~= nil then
        RestrictedByThis[restr][obj] = nil
    end
end)
