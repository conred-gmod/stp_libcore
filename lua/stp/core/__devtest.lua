-- Add test code into this file. Clear this file in release commits.

local libo = stp.obj
local libn = stp.obj.net

print("---- __devtest.lua start")

local META = libo.BeginObject("PerfectCasino.Poker")
libo.ApplyMany(META,
    libn.EasyComposite
)

libo.ConstructNestedType(META, "Fwd", libn.MakeEasyMsg(libn.schema.UInt(16), "fwd", "PingSend","PingRecv"))

libo.ConstructNestedType(META, "Rev", libn.MakeEasyMsg(libn.schema.UInt(16), "rev", "ReplySend","ReplyRecv"))

libo.ConstructNestedType(META, "Bank",
    libo.MakeVariableField,
    libo.MakeVariableAccessors(
        "GetBank",
        SERVER and "SetBank",
        "OnBankChanged"
    ),

    SERVER and libo.VariableDefault(0),

    libn.MakeVar(libn.schema.UInt(16)),
    libn.MakeRecipientEveryone,
    libn.MakeReliable
)

if SERVER then
    function META:NetGetRecipients(recip)
        recip:AddAllPlayers()
    end

    function META:NetTransmitInit()
    end
else
    function META:NetReceiveInit()
        return {}
    end
end

if CLIENT then
    function META:PingRecv(val)
        print("Got",val, "on client")
        self:ReplySend(val)
    end
end

if SERVER then
    function META:ReplyRecv(val, ply)
        print("Got",val,"from",ply)
    end
end

function META:Ping(val)
    self:PingSend(val)
end

function META:OnBankChanged(old, new)
    print(self, "New bank value = ", new)
end

function META:BankAdd(delta)
    self:SetBank(self:GetBank() + delta)
end

libo.HookAdd(META, "OnPreRemove", "Devtest.Debug", function(self)
    print(self, "Removing...")
end)

libo.Register(META)
--Poker.Game = META

local gameref = stp.GetPersistedTable("Devtest_Gameref", {})

local function TryRemove()
    local game = gameref.Value
    if game == nil then return end

    game:Remove()
    gameref.Value = nil
end

concommand.Add("stplib_devtest_create", function()
    TryRemove()

    local game = META:Create({})
    gameref.Value = game

    print("Created",game,game.TrackId)
end)

concommand.Add("stplib_devtest_remove", TryRemove)

concommand.Add("stplib_devtest_ping", function(_,_,args)
    local game = gameref.Value
    if game == nil then 
        print("Game is not initialized")
        return
    end

    local val = args[1]
    if val == nil then print("! One parameter required") return end
    
    local val = tonumber(val)
    if val == nil or val < 0 or val > 65535 or bit.tobit(val) ~= val then 
        print("! Parameter must be an integer from 0 to 65535") return 
    end

    game:Ping(val)
end)

concommand.Add("stplib_devtest_add", function(_,_,args)
    local game = gameref.Value
    if game == nil then 
        print("Game is not initialized")
        return
    end

    local val = args[1]
    if val == nil then print("! One parameter required") return end
    
    local val = tonumber(val)
    if val == nil or val < 0 or val > 65535 or bit.tobit(val) ~= val then 
        print("! Parameter must be an integer from 0 to 65535") return 
    end

    game:BankAdd(val)
end)

print("---- __devtest.lua end")