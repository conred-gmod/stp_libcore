local sobj = stp.obj
local sobjtrack = {}

sobj.Tracker = sobjtrack

local ID_BITS_NET = 23
sobjtrack.ID_BITS_NET = ID_BITS_NET
local ID_MAX = bit.lshift(1, ID_BITS_NET) - 1
sobjtrack.ID_MAX = ID_MAX
local ID_MIN = -bit.lshift(1, ID_BITS_NET)
sobjtrack.ID_MIN = ID_MIN

local ObjectsNet = stp.GetPersistedTable("stp.obj.tracker.ObjectsNet", {})
local ObjectsLocal = stp.GetPersistedTable("stp.obj.tracker.ObjectsLocal", {})

local function Track(obj, id)
    sobj.CheckFullyRegistered(obj)

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

local function GenerateIdLocal()
    return -table.SeqCount(ObjectsLocal) - 1
end

local function GenerateIdNet()
    return table.SeqCount(ObjectsNet) + 1
end

local function Untrack(obj)
    sobj.CheckFullyRegistered(obj)
    
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

function sobjtrack.GetAllNetworkable()
    return ObjectsNet
end

function sobjtrack.GetAllLocal()
    return ObjectsLocal
end

function sobjtrack.Get(id)
    if id > 0 then
        return ObjectsNet[id]
    else
        return ObjectsLocal[-id]
    end
end

function sobjtrack.IsNetworkable(arg)
    local id = arg
    if istable(arg) then
        id = arg.TrackId
    end

    return id > 0
end


local TRK = sobj.BeginTrait("stp.obj.Trackable")
sobj.Instance(TRK)
TRK.IsTrackable = true

sobj.HookDefine(TRK, "OnPreTracked")
sobj.HookDefine(TRK, "OnPostTracked")

sobj.HookAdd(TRK, "OnRemove", TRK.TypeName, Untrack)

sobj.Trackable = sobj.Register(TRK)



local TRKL = sobj.BeginTrait("stp.obj.TrackableLocal")
TRK(TRKL)

sobj.HookAdd(TRKL, "PostInit", TRKL.TypeName, function(self)
    Track(self, GenerateIdLocal())
end)

sobj.TrackableLocal = sobj.Register(TRKL)

local TRKN = sobj.BeginTrait("stp.obj.TrackableNetworked")
TRK(TRKN)

TRKN.IsTrackableNet = true

sobj.HookAdd(TRKN, "PostInit", TRKN.TypeName, function(self, params)
    local id = params.TrackId
    if SERVER then
        id = GenerateIdNet()
    else
        assert(isnumber(id) and id > 0)
    end

    Track(self, id)
end)
sobj.TrackableNetworked = sobj.Register(TRKN)