local libo = stp.obj
local libtrack = {}

local Tracker_Untrack

libo.Tracker = libtrack

local ID_BITS_NET = 23
libtrack.ID_BITS_NET = ID_BITS_NET
local ID_MAX = bit.lshift(1, ID_BITS_NET) - 1
libtrack.ID_MAX = ID_MAX
local ID_MIN = -bit.lshift(1, ID_BITS_NET)
libtrack.ID_MIN = ID_MIN

local TRK = libo.BeginTrait("stp.obj.Trackable")
libo.Instantiatable(TRK)
TRK.IsTrackable = true

libo.HookDefine(TRK, "OnPreTracked")
libo.HookDefine(TRK, "OnPostTracked")

libo.HookAdd(TRK, "OnRemove", TRK.TypeName, Tracker_Untrack)

libo.Register(TRK)
libo.Trackable = TRK

local ObjectsNet = stp.GetPersistedTable("stp.core.obj.tracker.ObjectsNet", {})
local ObjectsLocal = stp.GetPersistedTable("stp.core.obj.tracker.ObjectsLocal", {})

local function _Track(obj, id)
    libo.CheckFullyRegistered(obj)

    if not obj.IsTrackable then
        stp.Error(obj," is not trackable")
    end

    if obj.TrackId ~= nil then return end
    assert(id ~= 0, "Id is zero")
    assert(id >= ID_MIN and id <= ID_MAX, "Id is out-of-range")

    hook.Run("stp.obj.Tracker.OnPreTracked", obj, id)
    obj:OnPreTracked(obj, id)

    obj.TrackId = id
    if id > 0 then
        ObjectsNet[id] = obj
    else
        ObjectsLocal[-id] = obj
    end

    obj:OnPostTracked(obj)
    hook.Run("stp.obj.Tracker.OnPostTracked", obj)
end

Tracker_Untrack = function(obj)
    libo.CheckFullyRegistered(obj)
    
    if not obj.IsTrackable then
        stp.Error(obj," is not trackable")
    end

    local id = obj.TrackId
    if id == nil then return end

    obj.TrackId = nil
    if id > 0 then
        ObjectsNet[id] = nil
    else
        ObjectsLocal[-id] = nil
    end
end

function libtrack.GetAllNetworkable()
    return ObjectsNet
end

function libtrack.GetAllLocal()
    return ObjectsLocal
end

function libtrack.Get(id)
    if id > 0 then
        return ObjectsNet[id]
    else
        return ObjectsLocal[-id]
    end
end

function libtrack.IsNetworkable(arg)
    local id = arg
    if istable(arg) then
        id = arg.IsNetworkable
    end

    return id > 0
end



local TRKL = libo.BeginTrait("stp.obj.Track")