local libn = stp.obj.net
local libo = stp.obj

local function Attach(varmeta)
    local parentmeta = varmeta.OwnerType
    assert(parentmeta)

    local vartyname = varmeta.TypeName
    print("Attach", vartyname)

    local container_name
    if varmeta.IsSubobjNetworkStorable then
        parentmeta:RegisterSubobjNetwork(vartyname)
        container_name = "SubobjNetwork"
    else
        parentmeta:RegisterSubobjNetworkRev(vartyname)
        container_name = "SubobjNetworkRev"
    end
    
    libo.HookAdd(varmeta, "Init", "stp.obj.net.HighLevelAttach", function(self)    
        self.Owner[container_name]:SetByName(vartyname, self)
    end)

    libo.HookAdd(varmeta, "OnRemove", "stp.obj.net.HighLevelDetach", function(self)
        self.Owner[container_name]:SetByName(vartyname, nil)
    end)
end


local VARF = libo.BeginTrait("stp.obj.net.Var")
libn.Sendable(VARF)
libo.Variable(VARF)
libn.SendableInit(VARF)

libo.MarkAbstract(VARF, "SCHEMA", "table")

if SERVER then
    libo.HookAdd(VARF, "VariableOnSet", "stp.obj.net", function(self, old, new)
        if old == new then return end
        libn._MarkDirty(self)
    end)

    libo.HookAdd(VARF, "SubobjVariableOwner_Added", "stp.obj.net", function(self, params)
        self:NetSetRestrictor(self.Owner)
    end)

    function VARF:NetTransmit()
        self.SCHEMA.transmit(self:VariableGet())
    end

    function VARF:NetTransmitInit()
        self:NetTransmit()
    end

    -- TODO: transmit-on-connect
else
    libo.VariableRequireInit()(VARF)

    function VARF:NetReceive()
        self:VariableSet(self.SCHEMA.receive())
    end

    function VARF:NetReceiveInit()
        return {VarValue = self.SCHEMA.receive()}
    end
end

print(VARF, VARF.IsSubobjNetworkStorable)
libo.Register(VARF)

function libn.MakeVar(schema)
    return function(varmeta)
        libo.CheckNotFullyRegistered(varmeta)

        VARF(varmeta)
        varmeta.SCHEMA = schema
        Attach(varmeta)
    end
end



-- TODO: do not call :NetTransmitInit/:NetReceiveInit for these traits.
local MSGF = libo.BeginTrait("stp.obj.net.MsgUnbuffered")
local MSGR = libo.BeginTrait("stp.obj.net.MsgRevUnbuffered")

libn.Sendable(MSGF)
libn.SendableRev(MSGR)

local function Msg_InitMeta(meta, is_send_side)
    libo.MarkAbstract(meta, "SCHEMA", "table")

    if not is_send_side then
        libo.HookDefine(meta, "OnReceived")
    end
end

Msg_InitMeta(MSGF, SERVER)
Msg_InitMeta(MSGR, CLIENT)

local function Msg_Send(self, data)
    self._msg_data = data
    libn._MarkDirty(self)
end

local function Msg_Transmit(self, bytes_left)
    self.SCHEMA.transmit(self._msg_data, bytes_left)
    self._msg_data = nil
end

local function Msg_Receive(self, bytes)
    local data = self.SCHEMA.receive(bytes)

    self:OnReceived(data)
end

if SERVER then
    MSGF.Send = Msg_Send
    MSGF.NetTransmit = Msg_Transmit

    libo.HookAdd(MSGF, "SubobjVariableOwner_Added", "stp.obj.net", function(self, params)
        self:NetSetRestrictor(self.Owner)
    end)
else
    MSGF.NetReceive = Msg_Receive
end

if CLIENT then
    MSGR.Send = Msg_Send
    MSGR.NetTransmit = Msg_Transmit
else
    MSGR.NetReceive = Msg_Receive
end

libo.Register(MSGF)
libo.Register(MSGR)

local function GetAccessorName(msgmeta)
    return "__message_"..msgmeta.TypeName
end

local function MakeGenericMsg(trait, schema)
    return function(msgmeta)
        libo.MakeAttached(GetAccessorName(msgmeta))(msgmeta)

        trait(msgmeta)
        msgmeta.SCHEMA = schema
        Attach(msgmeta)
    end
end

function libn.MakeMsgFwd(schema, buffered)
    assert(buffered == false, "Buffered messages are not supported yet")

    return MakeGenericMsg(MSGF, schema)
end

function libn.MakeMsgRev(schema, buffered)
    assert(buffered == false, "Buffered messages are not supported yet")

    return MakeGenericMsg(MSGR, schema)
end

function libn.MakeMsgAccessors(send, receiver)
    return function(msgmeta)
        libo.CheckNotFullyRegistered(msgmeta)

        local ownermeta = msgmeta.OwnerType
        assert(ownermeta ~= nil)
        libo.CheckNotFullyRegistered(ownermeta)

        local msg_accessor = GetAccessorName(msgmeta)

        if msgmeta.Send ~= nil then
            ownermeta[send] = function(self, data)
                local msg = self[msg_accessor](self)

                msg:Send(data)
            end
        else
            libo.MarkAbstract(ownermeta, receiver, "function")

            libo.HookAdd(msgmeta, "OnReceived", function(self, data, sender)
                local owner = self.Owner
                owner[receiver](owner, data, receiver)
            end)
        end
    end
end


local ECOMP = libo.BeginTrait("stp.net.EasyComposite")
libo.ApplyMany(ECOMP,
    libn.Instantiatable,
    libn.MakeReliable,
    libo.VariableContainer
)

libo.Register(ECOMP)
libn.EasyComposite = ECOMP