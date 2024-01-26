-- Add test code into this file. Clear this file in release commits.

local libo = stp.obj
local libn = stp.obj.net

print("---- __devtest.lua start")

local META = libo.BeginObject("PerfectCasino.Poker")
libo.ApplyMany(META,
    libn.EasyComposite
)

libo.ConstructNestedType(META, "Fwd",
    libn.MakeMsgFwd(libn.schema.UInt(16), false),
    libn.MakeMsgAccessors("PingSend","PingRecv"),
    libn.MakeRecipientEveryone,
    libn.MakeReliable
)

libo.ConstructNestedType(META, "Rev",
    libn.MakeMsgRev(libn.schema.UInt(16), false),
    libn.MakeMsgAccessors("ReplySend","ReplyRecv"),
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

print("---- __devtest.lua end")