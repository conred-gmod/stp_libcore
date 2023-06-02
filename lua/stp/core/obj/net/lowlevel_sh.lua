local libo = stp.obj
local libn = stp.obj.net

local libaware = stp.obj.net.awareness

---------------------- Traits

local SEND = libo.BeginTrait("stp.obj.net.Sendable")
local SENDREV = libo.BeginTrait("stp.obj.net.SendableRev")

libn.Networkable(SEND)
libn.Networkable(SENDREV)

local MakeAbstractTxRx(meta, is_tx_side)
    if is_tx_side then
        libo.MarkAbstract(meta, "NetTransmit", "function")
    else
        libo.MarkAbstract(meta, "NetReceive", "function")
    end

    -- TODO: clear dirty flag when removed
end

MakeAbstractTxRx(SEND, SERVER)
MakeAbstractTxRx(SENDREV, CLIENT)

---------------------- Dirty Objects

local DirtyObjects = stp.GetPersistedTable("stp.obj.net.DirtyObjects", {})

function libn._MarkDirty(obj)
    assert(obj.NetTransmit ~= nil)

    DirtyObjects[obj] = true
end

---------------------- Net Messages

local Net_TxBeginInit
local Net_TxBeginData

local Net_TxEnd

local Net_HandleInit
local Net_HandleData

local NETSTRING = "stp.obj.net"

if SERVER then
    util.AddNetworkString(NETSTRING)

    Net_BeginInit = function(obj)
        net.Start(NETSTRING)

        -- TODO
    end

    -- TODO
end



---------------------- 

-- Returns true if object is actually removed
local function TransmitSingle_TryRemove(obj)
    -- TODO
end

local function TransmitSingle_Init(obj, recip)
    -- TODO
end

local function TransmitSingle_Data(obj)
    local recip

    if SERVER then
        recip = libaware._GetRecipients(obj)
        -- We have no recipients for data
        if recip == nil then return true end
    end

    
end

function libn._TransmitAll()
    local cleaned = {}

    if SERVER then
        for _, data in ipairs(libaware.NewlyAware) do
            local obj = data.Objects
            
            if TransmitSingle_TryRemove(obj) then continue end
            
            if  TransmitSingle_Init(obj, data.NewlyAware) and
                TransmitSingle_Data(obj) 
            then
                DirtyObjects[obj] = nil
            end
        end
    end

    for obj, _ in pairs(DirtyObjects) do
        if TransmitSingle_TryRemove(obj) then continue end

        if TransmitSingle(obj) then
            table.insert(cleaned, obj)
        end
    end

    for _, obj in ipairs(cleaned) do
        DirtyObjects[obj] = nil
    end
end