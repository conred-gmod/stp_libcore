local LIB = stp.obj

local MERGER = "stp.obj.Subobject"

LIB.MergerRegisterArray(MERGER, function(meta, key, array)
    local _, bitcount = math.frexp(math.max(#array - 1, 0))
    local desc = {
        IdToName = {},
        NameToId = {}
    }

    if not meta.IsTrait then
        desc.BitCount = bitcount
        desc.Count = #array
    end

    for i, pair in ipairs(array) do
        local name = pair.Key
        
        desc.IdToName[i] = name
        desc.NameToId[i] = name
    end

    meta[key.."Desc"] = desc
end)

function LIB.MakeSubobjectStorable(meta, key)
    if stp.DebugFlags.TypeSystem then
        print("stp.obj.MakeSubobjectStorable", meta, key)
    end

    meta["IsSubobj"..key.."Storable"] = true
end

local CONT = {}
CONT.__index = CONT

local function MakeContainer(desc, owner, key)
    local container = setmetatable({}, CONT)

    container._desc = desc
    container._owner = owner
    container.ById = {}
    container.ByName = {}

    function container._GetOwnerInfo(obj)
        if not obj["IsSubobj"..key.."Storable"] then
            stp.Error("Attempt to use non-'",key,"'-subobject in subobject container")
        end

        return obj["Subobj"..key.."Owner"]
    end

    function container._SetOwnerInfo(obj, value)
        if not obj["IsSubobj"..key.."Storable"] then
            stp.Error("Attempt to use non-'",key,"'-subobject in subobject container")
        end

        obj["Subobj"..key.."Owner"] = value
    end

    return container
end

function CONT:SetById(id, value)
    if value ~= nil then
        assert(self:_GetOwnerInfo(value) == nil, "Attempt to double-use object in subobject container")
    end

    local curvalue = self.ById[id]
    local name = self._desc.IdToName[id]
    if curvalue == value then return end

    if curvalue ~= nil then
        self:_SetOwnerInfo(curvalue, nil)
    end
    if value ~= nil then
        self:_SetOwnerInfo(value, {
            Owner = self._owner,
            SlotName = name,
            SlotId = id
        })
    end

    self.ById[id] = value
    self.ByName[name] = value
end

function CONT:SetByName(name, value)
    local id = self._desc.NameToId[name]
    self:SetById(id, value)
end

function CONT:ClearAll()
    local count = self._desc.Count
    local names = self._desc.IdToName

    for i = 1, count do
        local obj = self.ById[i]
        self:_SetOwnerInfo(obj, nil)

        self.ById[i] = nil
        self.ByName[names[i]] = nil
    end
end

function LIB.MakeSubobjectContainer(meta, key)
    if stp.DebugFlags.TypeSystem then
        print("stp.obj.MakeSubobjectContainer", meta, key)
    end

    meta["Is"..key.."SubobjContainer"] = true

    LIB.MergablesDeclare(meta, "Subobj"..key, MERGER)

    meta["RegisterSubobj"..key] = function(self, name)
        LIB.MergablesAdd(self, "Subobj"..key, name, MERGER)
    end

    LIB.HookAdd(meta, "Init", "___subobj_container_"..key, function(self, args)
        self["Subobj"..key] = MakeContainer(self["Subobj"..key.."Desc"], self, key)
    end)

    LIB.HookAdd(meta, "OnPreRemove", "___subobj_container_"..key, function(self)
        self["Subobj"..key]:ClearAll()
    end)

end