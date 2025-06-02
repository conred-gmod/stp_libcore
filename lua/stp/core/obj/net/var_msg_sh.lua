local snet = stp.obj.net
local sobj = stp.obj
local check_ty = stp.CheckType

local function Attach(varmeta)
    local parentmeta = varmeta.OwnerType
    assert(parentmeta)

    local vartyname = varmeta.TypeName

    local container_name
    if varmeta.IsSubobjNetworkStorable then
        parentmeta:RegisterSubobjNetwork(vartyname)
        container_name = "SubobjNetwork"
    else
        parentmeta:RegisterSubobjNetworkRev(vartyname)
        container_name = "SubobjNetworkRev"
    end
    
    sobj.HookAdd(varmeta, "Init", "stp.obj.net.HighLevelAttach", function(self)    
        self.Owner[container_name]:SetByName(vartyname, self)
    end)

    sobj.HookAdd(varmeta, "OnRemove", "stp.obj.net.HighLevelDetach", function(self)
        self.Owner[container_name]:SetByName(vartyname, nil)
    end)
end


local VARF = sobj.BeginTrait("stp.obj.net.Var")
snet.Sendable(VARF)
sobj.Variable(VARF)
--snet.SendableInit(VARF)

sobj.MarkAbstract(VARF, "SCHEMA", "table")

if SERVER then
    sobj.HookAdd(VARF, "VariableOnSet", "stp.obj.net", function(self, old, new)
        if old == new then return end
        snet._MarkDirty(self)
    end)

    sobj.HookAdd(VARF, "SubobjNetworkOwner_Added", "stp.obj.net", function(self, params)
        self:NetSetRestrictor(self.Owner)
    end)

    function VARF:NetTransmit()
        self.SCHEMA.transmit(self:VariableGet())
    end
  
--[[    function VARF:NetTransmitInit()
        self:NetTransmit()
    end]]

    -- TODO: transmit-on-connect
else
    function VARF:NetReceive()
        self:VariableSet(self.SCHEMA.receive())
    end

--[[    function VARF:NetReceiveInit()
        print(self, "VARF:NetReceiveInit", self.SCHEMA.receive)
        return {VarValue = self.SCHEMA.receive()}
    end]]
end

sobj.Register(VARF)

function snet.MakeVar(schema)
    return function(varmeta)
        sobj.CheckNotFullyRegistered(varmeta)

        VARF(varmeta)
        varmeta.SCHEMA = schema
        Attach(varmeta)
    end
end



-- TODO: do not call :NetTransmitInit/:NetReceiveInit for these traits.
local MSGF = sobj.BeginTrait("stp.obj.net.MsgUnbuffered")
local MSGR = sobj.BeginTrait("stp.obj.net.MsgRevUnbuffered")

snet.Sendable(MSGF)
snet.SendableRev(MSGR)

local function Msg_InitMeta(meta, is_send_side)
    sobj.MarkAbstract(meta, "SCHEMA", "table")
    meta.NetTransmitNewlyAware = false

    if not is_send_side then
        sobj.HookDefine(meta, "OnReceived")
    end
end

Msg_InitMeta(MSGF, SERVER)
Msg_InitMeta(MSGR, CLIENT)

local function Msg_Send(self, data)
    self._msg_data = data
    snet._MarkDirty(self)
end

local function Msg_Transmit(self)
    self.SCHEMA.transmit(self._msg_data)
    self._msg_data = nil
end

local function Msg_Receive(self, ply)
    local data = self.SCHEMA.receive(bytes)

    self:OnReceived(data, ply)
end

if SERVER then
    MSGF.Send = Msg_Send
    MSGF.NetTransmit = Msg_Transmit

    sobj.HookAdd(MSGF, "SubobjNetworkOwner_Added", "stp.obj.net", function(self, params)
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

sobj.Register(MSGF)
sobj.Register(MSGR)

local function GetAccessorName(msgmeta)
    return "__message_"..msgmeta.TypeName
end

local function MakeGenericMsg(trait, schema)
    return function(msgmeta)
        sobj.MakeAttached(GetAccessorName(msgmeta))(msgmeta)

        trait(msgmeta)
        msgmeta.SCHEMA = schema
        Attach(msgmeta)
    end
end

function snet.MakeMsgFwd(schema, buffered)
    assert(buffered == false, "Buffered messages are not supported yet")

    return MakeGenericMsg(MSGF, schema)
end

function snet.MakeMsgRev(schema, buffered)
    assert(buffered == false, "Buffered messages are not supported yet")

    return MakeGenericMsg(MSGR, schema)
end

function snet.MakeMsgAccessors(send, receiver)
    return function(msgmeta)
        sobj.CheckNotFullyRegistered(msgmeta)

        local ownermeta = msgmeta.OwnerType
        assert(ownermeta ~= nil)
        sobj.CheckNotFullyRegistered(ownermeta)

        local msg_accessor = GetAccessorName(msgmeta)

        if msgmeta.Send ~= nil then
            ownermeta[send] = function(self, data)
                local msg = self[msg_accessor](self)

                msg:Send(data)
            end
        else
            sobj.MarkAbstract(ownermeta, receiver, "function")

            sobj.HookAdd(msgmeta, "OnReceived", "stp.obj.net.MakeMsgAccessors", function(self, data, sender)
                local owner = self.Owner
                owner[receiver](owner, data, sender)
            end)
        end
    end
end


local ECOMP = sobj.BeginTrait("stp.net.EasyComposite")
sobj.ApplyMany(ECOMP,
    snet.Instantiatable,
    snet.MakeReliable,
    sobj.VariableContainer
)

sobj.Register(ECOMP)
snet.EasyComposite = ECOMP

function snet.MakeEasyVar(schema, getter, setter, default, extraparams)
    check_ty(schema, "schema", "table")
    extraparams = check_ty(extraparams, "extraparams", {"table", "nil"}) or {}

    local callback = extraparams.Callback

    local is_reliable = not extraparams.Unreliable
    local add_autorecip = not extraparams.NoAutoRecipientEveryoune
    
    local has_default = SERVER and default ~= nil
    if SERVER and extraparams.DefaultIsNil then
        assert(default == nil, "Setting 'default' to non-nil value and 'extraparams.DefaultIsNil' to true simultenously is not allowed")

        has_default = true
    end

    return function(meta)
        sobj.MakeVariableField(meta)
        snet.MakeVar(schema)(meta)

        if has_default then
            sobj.VariableDefault(default)(meta)
        end

        sobj.MakeVariableAccessors(getter, setter, callback)(meta)

        function meta:NetIsUnreliable() return is_reliable end

        if add_autorecip then
            snet.MakeRecipientEveryone(meta)
        end
    end
end

function snet.MakeEasyMsg(schema, dir, accessor_send, accessor_recv, extraparams)
    check_ty(schema, "schema", "table")
    assert(dir == "fwd" or dir == "rev", "'dir' is netiher \"fwd\" nor \"rev\"")
    
    extraparams = check_ty(extraparams, "extraparams", {"table", "nil"}) or {}

    local is_buffered = extraparams.Buffered or false
    local is_reliable = not extraparams.Unreliable
    local is_fwd = dir == "fwd"
    local add_autorecip = not extraparams.NoAutoRecipientEveryoune

    assert((accessor_send == nil) == (accessor_recv == nil))
    assert(not is_buffered, "Buffered messages are not implemented yet")

    return function(meta)
        MakeGenericMsg(is_fwd and MSGF or MSGR, schema)(meta)

        if accessor_send ~= nil then
            snet.MakeMsgAccessors(accessor_send, accessor_recv)(meta)
        end

        function meta:NetIsUnreliable() return is_reliable end

        if add_autorecip then
            snet.MakeRecipientEveryone(meta)
        end
    end
end