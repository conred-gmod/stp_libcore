-- Add test code into this file. Clear this file in release commits.

local libo = stp.obj
local libn = stp.obj.net

print("---- __devtest.lua start")

local META = libo.BeginObject("PerfectCasino.Poker")
libo.ApplyMany(META,
    libn.Instantiatable,
    libo.VariableContainer
)

libo.ConstructNestedType(META, "Bank",
    libo.MakeVariableField,
    libo.MakeVariableAccessors(
        "GetBank",
        SERVER and "SetBank",
        "OnBankChanged"
    ),

    CLIENT and libo.VariableRequireInit(),
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
        net.WriteUInt(self:GetBank(), 16)
    end
else
    function META.NetReceiveInit()
        local bank = net.ReadUInt(16)
        return { Bank = bank }
    end
end


function META:OnBankChanged(old, new)
    print(self, "New bank value = ", new)
end

libo.Register(META)
--Poker.Game = META

print("Debug", META.Init)

function CreateGame()
    local obj = META:Create({
        
    })

    return obj
end

concommand.Add("stplib_devtest", function()
    CreateGame()
end)

print("---- __devtest.lua end")