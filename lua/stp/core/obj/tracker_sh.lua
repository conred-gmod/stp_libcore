local LIB = stp.obj
local TRK = {}
LIB.Tracker = TRK

local ID_BITS_NET = 23
TRK.ID_BITS_NET = ID_BITS_NET
local ID_MAX = bit.lshift(1, ID_BITS_NET) - 1
TRK.ID_MAX = ID_MAX
local ID_MIN = -bit.lshift(1, ID_BITS_NET)
TRK.ID_MIN = ID_MIN

local TRACKABLE = LIB.BeginTrait("stp.obj.Trackable")
LIB.Instantiatable(TRACKABLE)
TRACKABLE.IsTrackable = true

LIB.HookDefine(TRACKABLE, "OnPreTracked")
LIB.HookDefine(TRACKABLE, "OnPostTracked")
LIB.HookDefine(TRACKABLE, "OnPreUntracked")
LIB.HookDefine(TRACKABLE, "OnPostUntracked")

LIB.Register(TRACKABLE)
LIB.Trackable = TRACKABLE

local ObjectsNet = stp.GetPersistedTable("stp.core.obj.tracker.ObjectsNet", {})
local ObjectsLocal = stp.GetPersistedTable("stp.core.obj.tracker.ObjectsLocal", {})

function TRK._Track(obj, id)
    LIB.CheckFullyRegistered(obj)

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

function TRK._Untrack(obj)
    LIB.CheckFullyRegistered(obj)
    
    if not obj.IsTrackable then
        stp.Error(obj," is not trackable")
    end

    local id = obj.TrackId
    if id == nil then return end

    hook.Run("stp.obj.Tracker.OnPreUntracked", obj)
    obj:OnPreUntracked(obj)

    obj.TrackId = nil
    if id > 0 then
        ObjectsNet[id] = nil
    else
        ObjectsLocal[-id] = nil
    end

    obj:OnPostUntracked(obj, id)
    hook.Run("stp.obj.Tracker.OnPostUntracked", obj, id)
end

function TRK.GetAllNetworkable()
    return ObjectsNet
end

function TRK.GetAllLocal()
    return ObjectsLocal
end

function TRK.Get(id)
    if id > 0 then
        return ObjectsNet[id]
    else
        return ObjectsLocal[-id]
    end
end

function TRK.IsNetworkable(arg)
    local id = arg
    if istable(arg) then
        id = arg.IsNetworkable
    end

    return id > 0
end