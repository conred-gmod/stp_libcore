local libn = stp.obj.net
local libo = stp.obj

local VARF = libo.BeginTrait("stp.obj.net.Var")
libn.Sendable(VARF)
libo.Variable(VARF)

libo.MarkAbstract(VARF, "SCHEMA", "table")

if SERVER then
    libo.HookAdd(VARF, "VariableOnSet", "stp.obj.net", function(self, old, new)
        if old == new then return end
        libn._MarkDirty(self)
    end)

    libo.HookAdd(VARF, "PostInit", "stp.obj.net", function(self, params)
        self:NetSetRestrictor(self.Owner)
    end)

    function VARF:NetTransmit(bytes_left)
        self.SCHEMA.transmit(self:VariableGet(), bytes_left)
    end

    -- TODO: transmit-on-connect
else
    function VARF:NetReceive(bytes)
        self:VariableSet(self.SCHEMA.receive(bytes))
    end
end

libo.Register(VARF)

function libn.MakeVar(schema)
    return function(varmeta)
        libo.CheckNotFullyRegistered(varmeta)

        VARF(varmeta)
        varmeta.SCHEMA = schema
    end
end




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

    libo.HookAdd(MSGF, "PostInit", "stp.obj.net", function(self, params)
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