local LIB = stp.obj.net.schema
local libobj = stp.obj

-- Do not add:
--[[
    net.[Read/Write]Type
    net.[Read/Write]Table

]]


LIB.String = {
    transmit = net.WriteString,
    receive = net.ReadString
}

LIB.Float32 = {
    transmit = net.WriteFloat,
    receive = net.ReadFloat
}

LIB.Float64 = {
    transmit = net.WriteDouble,
    receive = net.ReadDouble
}

LIB.Nothing_ReturnDefault = function(default)
    return {
        transmit = function() end,
        receive = function() return default end
    }
end

LIB.Int = function(bits)
    if bits == 0 then
        return LIB.Nothing_ReturnDefault(0)
    end

    return {
        transmit = function(n) net.WriteInt(n, bits) end,
        receive = function() net.ReadInt(bits) end
    }
end

LIB.UInt = function(bits)
    if bits == 0 then
        return LIB.Nothing_ReturnDefault(0)
    end

    return {
        transmit = function(n) net.WriteUInt(n, bits) end,
        receive = function() net.ReadUInt(bits) end
    }
end

LIB.Bool = {
    transmit = net.WriteBool,
    receive = net.ReadBool
}


---

LIB.Entity = {
    transmit = net.WriteEntity,
    receive = net.ReadEntity
}


local _, PLAYER_BITS = math.frexp(game.MaxPlayers() - 1)

if PLAYER_BITS ~= 0 then
    LIB.EntityPlayer = {
        transmit = function(ply)
            net.WriteUInt(ply:EntIndex() - 1, PLAYER_BITS)
        end,
        receive = function()
            return Entity(net.ReadUInt(PLAYER_BITS) + 1)
        end
    }
else
    LIB.EntityPlayer = {
        transmit = function(ply) end,
        receive = function()
            return Entity(1)
        end
    }
end

local OBJ_TRK_BITS = libobj.Tracker.ID_BITS_NET
local OBJ_VARBITS_BITS = 8

-- TODO: docs

local function WriteStpObject(obj)
    if obj == nil then
        net.WriteUInt(0, OBJ_TRK_BITS)
        return
    end
    
    local data = {}
    local varbits = 0

    while true do
        local ownerdata = obj.SubobjNetworkOwner
        if ownerdata == nil then
            table.insert(data, obj.TrackId)
            break
        else
            local bits = ownerdata.Owner.SubobjNetworkDesc.Bits
            varbits = varbits + bits
            table.insert(data, {
                bits = bits,
                data = ownerdata.SlotId - 1
            })
        end
    end

    local rootid = table.remove(data)
    data = table.Reverse(data) -- TODO: reverse in place

    net.WriteUInt(rootid, OBJ_TRK_BITS)
    net.WriteUInt(varbits, OBJ_VARBITS_BITS)

    for _, pair in ipairs(data) do
        if pair.bits ~= 0 then
            net.WriteUInt(pair.data, pair.bits)
        end
    end
end

local function ReadStpObject()
    local root = net.ReadUInt(OBJ_TRK_BITS)
    if root == 0 then return nil end
    
    local obj = libobj.Tracker.Get(root)
    assert(obj ~= nil)

    local varbits = net.ReadUInt(OBJ_VARBITS_BITS)
    
    while varbits ~= 0 do
        local objbits = obj.SubobjNetworkDesc.Bits
        local subid = 1
        if objbits ~= 0 then
            subid = net.ReadUInt(objbits) + 1
        end

        obj = obj.SubobjNetwork.ById[subid]
    end
    
    return obj
end

LIB.StpObject = {
    transmit = WriteStpObject
    receive = ReadStpObject
}


---

LIB.VectorWorldPos = {
    transmit = net.WriteVector,
    receive = net.ReadVector
}

LIB.VectorUnit = {
    transmit = net.WriteNormal,
    receive = net.ReadNormal
}

LIB.Angle = {
    transmit = net.WriteAngle,
    receive = net.ReadAngle
}

LIB.Matrix4x4 = {
    transmit = net.WriteMatrix,
    receive = net.ReadMatrix
}

LIB.ColorRGB = {
    transmit = function(clr) net.WriteColor(clr, false) end,
    receive = function() return net.ReadColor(false) end
}

LIB.ColorRGBA = {
    transmit = net.WriteColor,
    receive = net.ReadColor
}