local snetschema = stp.obj.net.schema
local sobj = stp.obj

-- Do not add:
--[[
    net.[Read/Write]Type
    net.[Read/Write]Table

]]


snetschema.String = {
    transmit = net.WriteString,
    receive = net.ReadString
}

snetschema.Float32 = {
    transmit = net.WriteFloat,
    receive = net.ReadFloat
}

snetschema.Float64 = {
    transmit = net.WriteDouble,
    receive = net.ReadDouble
}

snetschema.Nothing_ReturnDefault = function(default)
    return {
        transmit = function() end,
        receive = function() return default end
    }
end

snetschema.Int = function(bits)
    if bits == 0 then
        return snetschema.Nothing_ReturnDefault(0)
    end

    return {
        transmit = function(n) net.WriteInt(n, bits) end,
        receive = function() return net.ReadInt(bits) end
    }
end

snetschema.UInt = function(bits)
    if bits == 0 then
        return snetschema.Nothing_ReturnDefault(0)
    end

    return {
        transmit = function(n) net.WriteUInt(n, bits) end,
        receive = function() return net.ReadUInt(bits) end
    }
end

snetschema.Bool = {
    transmit = net.WriteBool,
    receive = net.ReadBool
}


---

snetschema.Entity = {
    transmit = net.WriteEntity,
    receive = net.ReadEntity
}


local _, PLAYER_BITS = math.frexp(game.MaxPlayers() - 1)

if PLAYER_BITS ~= 0 then
    snetschema.EntityPlayer = {
        transmit = function(ply)
            net.WriteUInt(ply:EntIndex() - 1, PLAYER_BITS)
        end,
        receive = function()
            return Entity(net.ReadUInt(PLAYER_BITS) + 1)
        end
    }
else
    snetschema.EntityPlayer = {
        transmit = function(ply) end,
        receive = function()
            return Entity(1)
        end
    }
end

local OBJ_TRK_BITS = sobj.Tracker.ID_BITS_NET
local OBJ_PARTS_BITS = 4

local function WriteStpObject(obj, revnet)
    if obj == nil then
        net.WriteUInt(0, OBJ_TRK_BITS)
        return
    end
    
    local data = {}

    if (revnet and obj.SubobjNetworkRevOwner) or (not revnet and obj.SubobjNetworkOwner) then
        if revnet then
            data[1] = {
                bits = obj.SubobjNetworkRevOwner.Owner.SubobjNetworkRevDesc.Bits,
                data = obj.SubobjNetworkRevOwner.SlotId
            }
            obj = obj.SubobjNetworkRevOwner.Owner
        else
            data[1] = {
                bits = obj.SubobjNetworkOwner.Owner.SubobjNetworkDesc.Bits,
                data = obj.SubobjNetworkOwner.SlotId
            }
            obj = obj.SubobjNetworkOwner.Owner
        end
    end

    while true do
        local ownerdata = obj.SubobjNetworkOwner
        if ownerdata == nil then
            table.insert(data, {
                bits = 0,
                data = obj.TrackId,
            })
            break
        else
            local bits = ownerdata.Owner.SubobjNetworkDesc.Bits
            table.insert(data, {
                bits = bits,
                data = ownerdata.SlotId
            })

            obj = ownerdata.Owner
        end
    end

    local rootid = table.remove(data).data
    table.ReverseInplace(data)

    net.WriteUInt(rootid, OBJ_TRK_BITS)
    net.WriteUInt(#data, OBJ_PARTS_BITS)

    for _, pair in ipairs(data) do
        if pair.bits ~= 0 then
            net.WriteUInt(pair.data - 1, pair.bits)
        end
    end
end

local function ReadStpObject_FinalId(revnet)
    local root = net.ReadUInt(OBJ_TRK_BITS)
    if root == 0 then return nil end
    
    local obj = sobj.Tracker.Get(root)
    
    local subobj_count = net.ReadUInt(OBJ_PARTS_BITS)
    if obj == nil or subobj_count == 0 then return nil, root end

    for i = 1, subobj_count - 1 do
        local objbits = obj.SubobjNetworkDesc.Bits
        local subid = 1
        if objbits ~= 0 then
            subid = net.ReadUInt(objbits) + 1
        end

        obj = obj.SubobjNetwork.ById[subid]
        assert(obj ~= nil)
    end

    local subid = 1
    local bits
    if revnet then
        bits = obj.SubobjNetworkRevDesc.Bits
    else
        bits = obj.SubobjNetworkDesc.Bits
    end

    if bits ~= 0 then
        subid = net.ReadUInt(bits) + 1
    end

    
    return obj, subid
end

snetschema.ReadNetworkableAny_FinalId = ReadStpObject_FinalId


local function GetStpObject(parent, id, revnet)
    if parent == nil then
        return sobj.Tracker.Get(id)
    elseif revnet then
        return parent.SubobjNetworkRev.ById[id]
    else
        return parent.SubobjNetwork.ById[id]
    end
end

stp.obj.net._GetNetworkableFromParentAndId = GetStpObject


local function ReadStpObject(revnet)
    local parent, id = ReadStpObject_FinalId(revnet)

    return GetStpObject(parent, id, revnet)
end

snetschema.StpNetworkable = {
    transmit = function(obj) WriteStpObject(obj, false) end,
    receive = function() return ReadStpObject(false) end
}

snetschema.StpNetworkableRev = {
    transmit = function(obj) WriteStpObject(obj, true) end,
    receive = function() return ReadStpObject(true) end
}

---

snetschema.VectorWorldPos = {
    transmit = net.WriteVector,
    receive = net.ReadVector
}

snetschema.VectorUnit = {
    transmit = net.WriteNormal,
    receive = net.ReadNormal
}

snetschema.Angle = {
    transmit = net.WriteAngle,
    receive = net.ReadAngle
}

snetschema.Matrix4x4 = {
    transmit = net.WriteMatrix,
    receive = net.ReadMatrix
}

snetschema.ColorRGB = {
    transmit = function(clr) net.WriteColor(clr, false) end,
    receive = function() return net.ReadColor(false) end
}

snetschema.ColorRGBA = {
    transmit = net.WriteColor,
    receive = net.ReadColor
}