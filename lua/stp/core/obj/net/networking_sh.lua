local sobj = stp.obj
local snet = stp.obj.net
local snetschema = stp.obj.net.schema
local snetaware = stp.obj.net.awareness

local Net_RecvCreate
local Net_RecvRemove

---------------------- Traits

local SEND = sobj.BeginTrait("stp.obj.net.Sendable")
local SENDREV = sobj.BeginTrait("stp.obj.net.SendableRev")

if SERVER then
    SEND.NetTransmitNewlyAware = true
end

snet.Networkable(SEND)
snet.NetworkableRev(SENDREV)

local function MakeAbstractTxRx(meta, is_tx_side)
    if is_tx_side then
        sobj.MarkAbstract(meta, "NetIsUnreliable", "function")
        sobj.MarkAbstract(meta, "NetTransmit", "function")
    else
        sobj.MarkAbstract(meta, "NetReceive", "function")
    end
end

MakeAbstractTxRx(SEND, SERVER)
MakeAbstractTxRx(SENDREV, CLIENT)

snet.Sendable = sobj.Register(SEND)
snet.SendableRev = sobj.Register(SENDREV)

local SENDINIT = sobj.BeginTrait("stp.obj.net.SendableInit")
snet.Networkable(SENDINIT)

if SERVER then
    sobj.MarkAbstract(SENDINIT, "NetTransmitInit", "function")
else
    sobj.MarkAbstract(SENDINIT, "NetReceiveInit", "function")
end

snet.SendableInit = sobj.Register(SENDINIT)

local INST = sobj.BeginTrait("stp.obj.net.Instance")

sobj.ApplyMany(INST,
    snet.NetworkableComposite,
    sobj.TrackableNetworked,
    SENDINIT
)

if CLIENT then
    sobj.HookAdd(INST, "Init", INST.TypeName, function(self, params)
        if params.__InitFromNetwork ~= true then
            stp.Error("Attempt to manually create object of type '",self.TypeName,"' clientside.\n",
                "Objects of this type can only be created on server and networked to client!")
        end
    end)

    sobj.HookAdd(INST, "OnPreRemove", INST.TypeName, function(self, cascaded)
        
        if (not cascaded and self.__RemoveFromNetwork ~= true)
            or (cascaded and SubobjNetworkDesc.Owner.__RemoveFromNetwork ~= true) 
        then
            stp.Error("Attempt to manually remove object of type '",self.TypeName,"' clientside.")
        end

        -- For cascading
        self.__RemoveFromNetwork = true
    end)
end

INST.IsNetInstance = true

snet.Instance = sobj.Register(INST)


---------------------- Dirty Objects

local DirtyObjects = stp.GetPersistedTable("stp.obj.net.DirtyObjects", {})

function snet._MarkDirty(obj)
    assert(obj.NetTransmit ~= nil)

    DirtyObjects[obj] = true
end

---------------------- Net Messages

local NETSTRING = "stp.obj.net"

if SERVER then
    util.AddNetworkString(NETSTRING)
end

local Net_WriteObj = snetschema[SERVER and "StpNetworkable" or "StpNetworkableRev"].transmit
local Net_ReadObj_FinalId = snetschema.ReadNetworkableAny_FinalId

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
        if obj.NetTransmitInit == nil then return end

        net.Start(NETSTRING)
            Net_WriteObj(obj)
            net.WriteString(obj.TypeName)
            obj:NetTransmitInit()
        net.Send(recip)
    end

    Net_SendRemove = function(obj, recip)
        assert(obj.IsNetInstance)

        net.Start(NETSTRING)
            Net_WriteObj(obj)
        net.Send(recip)
    end
end

net.Receive(NETSTRING, function(_, sender)
    local parentobj, id = Net_ReadObj_FinalId(SERVER)
    if parentobj == nil and id == 0 then return end

    local obj = snet._GetNetworkableFromParentAndId(parentobj, id, SERVER)

    if obj == nil then -- Initialize 
        if SERVER then return end

        local typename = net.ReadString()
        local meta = sobj.GetObjectMetatables()[typename]
        local params = meta:NetReceiveInit()

        Net_RecvCreate(parentobj, id, meta, params)
    elseif obj.IsNetInstance then -- Remove 
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
        if not obj.IsNetInstance then return end
        if cascaded then return end -- If removal is cascaded on server, it will be cascaded on client too.

        local recip = snetaware._GetRecipients(obj)
        if recip == nil then return end

        Net_SendRemove(obj, recip)
    end)
end

hook.Add("stp.obj.PreRemoved", "spt.obj.net.ClearDirty", function(obj, _)
    DirtyObjects[obj] = nil
end)

local function TransmitSingle_Data(obj, newly_aware)
	if obj.NetTransmit == nil then return true end
    if newly_aware and not obj.NetTransmitNewlyAware then return true end
    
    local recip
    if SERVER then
        recip = snetaware._GetRecipients(obj)
        -- We have no recipients for data
        if recip == nil then return true end
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
        snetaware._MarkAware(obj, recip)  
    end
end

function snet._TransmitAll()
    local cleaned = {}

    if SERVER then
        for _, data in ipairs(snetaware._GetNewlyAware()) do
            local obj = data.Object
            TransmitSingle_Init(obj, data.NewlyAware)

            if TransmitSingle_Data(obj, true) then
                DirtyObjects[obj] = nil
            end
        end
    end

    for obj, _ in pairs(DirtyObjects) do
        if TransmitSingle_Data(obj, false) then
            table.insert(cleaned, obj)
        end
    end

    for _, obj in ipairs(cleaned) do
        DirtyObjects[obj] = nil
    end
end

--------------------

function snet.MakeUnreliable(meta)
    function meta:NetIsUnreliable() return true end
end

function snet.MakeReliable(meta)
    function meta:NetIsUnreliable() return false end
end