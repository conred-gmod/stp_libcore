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

    function VARF:NetTransmit(bytes_left)
        self.SCHEMA.transmit(self:VariableGet(), bytes_left)
    end

    -- TODO: transmit-on-connect
else
    function VAR:NetReceive(bytes)
        self:VariableSet(self.SCHEMA.receive(bytes))
    end
end

libo.Register(VARF)




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