local check_ty = STPLib.CheckType

local LIB = STPLib.Obj

LIB.OBJECT_ID_BITS = 24
LIB.OBJECT_ID_MAX = bit.lshift(1, LIB.OBJECT_ID_BITS) - 1



local TRACKER = TRACKER or {}
TRACKER.__index = TRACKER

local Trackers = Trackers or {}
local TrackersForTypes = TrackersForTypes or {}

function LIB.CreateTracker(name)
    check_ty(name, "name", "string")

    if Trackers[name] ~= nil then return Trackers[name] end

    local trk = setmetatable({}, TRACKER)
    trk.Name = name
    trk.Objects = {}

    Trackers[name] = trk
    return trk
end

function LIB.GetTracker(name)
    return Trackers[name]
end

function TRACKER:RegisterType(meta)
    assert(meta.OnPreRemoved ~= nil and meta.Initialize ~= nil)

    local typename = check_ty(meta.Type, "meta.Type", "string")

    TrackersForTypes[typename] = TrackersForTypes[typename] or {}

    TrackersForTypes[typename][self.Name] = self
end

function TRACKER:GetObject(id)
    return self.Objects[id]
end

function TRACKER:GetId(obj)
    local trackinfo = obj.___trackable
    assert(trackinfo != nil)
    
    local id = trackinfo.ids[self.Name]
    assert(id ~= nil)
    return id
end

function TRACKER:_GenerateId()
    local newidx = STPLib.SeqCount(self.Objects) + 1

    if newidx > LIB.OBJECT_ID_MAX then
        STPLib.Error("Too many active objects tracked in '",self.Name,"'")
    end

    return newidx
end

function TRACKER:IsTracked(typename)
    local trks = TrackersForTypes[typename]
    if trks == nil then return false end

    return trks[self.Name] ~= nil
end

hook.Add("STPLib.Obj._InternalCreate", "Trackable", function(obj, arg)
    local trackers = TrackersForTypes[obj.Type]
    if trackers == nil or table.IsEmpty(trackers) then return end


    local indices = arg.Tracker_CustomIndices or {}
    obj.___trackable = { ids = {} }

    for tracker_name, tracker in pairs(trackers) do
        tracker:_Register(obj, indices[tracker_name])
    end
end)

function TRACKER:OnRegistered(obj)
    -- To be overriden
end

function TRACKER:_Register(obj, index)
    local index_tbl = obj.___trackable.ids
    assert(index_tbl[self.Name] == nil, "Object is double-registered in some tracker")

    if index == 0 then
        return
    elseif index == nil then
        index = self:_GenerateId()
    end

    index_tbl[self.Name] = index
    self.Objects[index] = obj

    self:OnRegistered(obj)
    hook.Run("STPLib.Obj.OnRegistered", obj, self)
end

hook.Add("STPLib.Obj.OnPostRemoved", "aaaaa___STPLib.Trackable", function(obj, cascaded)
    local trackers = TrackersForTypes[obj.Type]
    if trackers == nil or table.IsEmpty(trackers) then return end

    for tracker_name, id in pairs(obj.___trackable.ids) do
        local tracker = Trackers[tracker_name]
        tracker:_Unregister(obj, id, cascaded)
    end

    obj.___trackable = nil
end)

function TRACKER:OnPreUnregistered(obj, cascaded)
    -- To be overriden
end

function TRACKER:_Unregister(obj, id, cascaded)
    self:OnPreUnregistered(obj, cascaded)
    hook.Run("STPLib.Obj.OnPreUnregistered", obj, self, cascaded)

    self.Objects[id] = nil
end