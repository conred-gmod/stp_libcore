local libo = stp.obj
local libn = stp.obj.net
local libsch = stp.obj.net.schema
local libaware = stp.obj.net.awareness

local Net_RecvCreate
local Net_RecvRemove

---------------------- Traits

local SEND = libo.BeginTrait("stp.obj.net.Sendable")
local SENDREV = libo.BeginTrait("stp.obj.net.SendableRev")

libn.Networkable(SEND)
libn.NetworkableRev(SENDREV)

local function MakeAbstractTxRx(meta, is_tx_side)
    if is_tx_side then
        libo.MarkAbstract(meta, "NetIsUnreliable", "function")
        libo.MarkAbstract(meta, "NetTransmit", "function")
    else
        libo.MarkAbstract(meta, "NetReceive", "function")
    end
end

MakeAbstractTxRx(SEND, SERVER)
MakeAbstractTxRx(SENDREV, CLIENT)

libo.Register(SEND)
libo.Register(SENDREV)
libn.Sendable = SEND
libn.SendableRev = SENDREV

local SENDINIT = libo.BeginTrait("stp.obj.net.SendableInit")
libn.Networkable(SENDINIT)

if SERVER then
    libo.MarkAbstract(SENDINIT, "NetTransmitInit", "function")
else
    libo.MarkAbstract(SENDINIT, "NetReceiveInit", "function")
end

libo.Register(SENDINIT)
libn.SendableInit = SENDINIT

local INST = libo.BeginTrait("stp.obj.net.Instantiatable")

libo.ApplyMany(INST,
    libn.NetworkableComposite,
    libo.TrackableNetworked,
    SENDINIT
)

if CLIENT then
    libo.HookAdd(INST, "Init", INST.TypeName, function(self, params)
        if params.__InitFromNetwork ~= true then
            stp.Error("Attempt to manually create object of type '",self.TypeName,"' clientside.\n",
                "Objects of this type can only be created on server and networked to client!")
        end
    end)

    libo.HookAdd(INST, "OnPreRemove", INST.TypeName, function(self, cascaded)
        
        if (not cascaded and self.__RemoveFromNetwork ~= true)
            or (cascaded and SubobjNetworkDesc.Owner.__RemoveFromNetwork ~= true) 
        then
            stp.Error("Attempt to manually remove object of type '",self.TypeName,"' clientside.")
        end

        -- For cascading
        self.__RemoveFromNetwork = true
    end)
end

INST.IsNetInstantiatable = true

libo.Register(INST)
libn.Instantiatable = INST


---------------------- Dirty Objects

local DirtyObjects = stp.GetPersistedTable("stp.obj.net.DirtyObjects", {})

function libn._MarkDirty(obj)
    print("MarkDirty", obj)
    assert(obj.NetTransmit ~= nil)

    DirtyObjects[obj] = true
end

---------------------- Net Messages

local NETSTRING = "stp.obj.net"

if SERVER then
    util.AddNetworkString(NETSTRING)
end

local Net_WriteObj = libsch[SERVER and "StpNetworkable" or "StpNetworkableRev"].transmit
local Net_ReadObj_FinalId = libsch.ReadNetworkableAny_FinalId

local function Net_SendData(obj, recip, unreliable)
    net.Start(NETSTRING, unreliable)

    Net_WriteObj(obj)
    obj:NetTransmit()


    if SERVER then
        net.Send(recip)
    else
        net.SendToServer()
    end
end

local Net_SendRemove
local Net_SendInit
if SERVER then
    Net_SendInit = function(obj, recip)
        net.Start(NETSTRING)
            Net_WriteObj(obj)
            net.WriteString(obj.TypeName)
            obj:NetTransmitInit()
        net.Send(recip)
    end

    Net_SendRemove = function(obj, recip)
        assert(obj.IsNetInstantiatable)

        net.Start(NETSTRING)
            Net_WriteObj(obj)
        net.Send(recip)
    end
end

net.Receive(NETSTRING, function(_, sender)
    local parentobj, id = Net_ReadObj_FinalId(SERVER)
    if parentobj == nil and id == 0 then return end

    local obj = libn._GetNetworkableFromParentAndId(parentobj, id, SERVER)

    if obj == nil then -- Initialize 
        if SERVER then return end

        local typename = net.ReadString()
        local meta = libo.GetObjectMetatables()[typename]

        local params = meta:NetReceiveInit()

        Net_RecvCreate(parentobj, id, meta, params)
    elseif obj.IsNetInstantiatable then -- Remove 
        if SERVER then return end

        Net_RecvRemove(obj)
    else
        obj:NetReceive(sender)
    end
end)

---------------------- 

if CLIENT then
    Net_RecvCreate = function(parentobj, id, meta, params)
        params.__InitFromNetwork = true

        if meta.IsTrackableNet then 
            assert(parentobj == nil)
            params.TrackId = id
        end

        local obj = meta:Create(params)

        if parentobj ~= nil then
            parentobj.SubobjNetwork:SetById(id, obj)
        end
    end

    Net_RecvRemove = function(obj)
        obj.__RemoveFromNetwork = true

        obj:Remove(false)
    end

end

if SERVER then
    hook.Add("stp.obj.PreRemoved", "stp.obj.net.TransmitRemove", function(obj, cascaded)
        if not obj.IsNetInstantiatable then return end
        if not cascaded then return end

        local recip = libaware._GetRecipients(obj)
        if recip == nil then return end

        Net_SendRemove(obj, recip)
    end)
end

hook.Add("stp.obj.PreRemoved", "spt.obj.net.ClearDirty", function(obj, _)
    DirtyObjects[obj] = nil
end)

local function TransmitSingle_Data(obj)
    print("TransmitSingle_Data", obj)

    if obj.NetTransmit == nil then print("- No transmit") return true end

    local recip

    if SERVER then
        recip = libaware._GetRecipients(obj)
        -- We have no recipients for data
        if recip == nil then print("- No recip") return true end
    end

    local unreliable = obj:NetIsUnreliable()

    -- TODO: add networking rate limiting here: return false when not transmitted

    Net_SendData(obj, recip, unreliable)
    return true
end

local TransmitSingle_Init
if SERVER then
    TransmitSingle_Init = function(obj, recip)
        Net_SendInit(obj, recip)
        libaware._MarkAware(obj, recip)  
    end
end

function libn._TransmitAll()
    local cleaned = {}

    if SERVER then
        for _, data in ipairs(libaware._GetNewlyAware()) do
            local obj = data.Object
            print("Newly aware", obj)
            
            TransmitSingle_Init(obj, data.NewlyAware)

            if TransmitSingle_Data(obj) then
                DirtyObjects[obj] = nil
            end
        end
    end

    for obj, _ in pairs(DirtyObjects) do
        if TransmitSingle_Data(obj) then
            table.insert(cleaned, obj)
        end
    end

    for _, obj in ipairs(cleaned) do
        DirtyObjects[obj] = nil
    end
end

--------------------

function libn.MakeUnreliable(meta)
    function meta:NetIsUnreliable() return true end
end

function libn.MakeReliable(meta)
    function meta:NetIsUnreliable() return false end
end