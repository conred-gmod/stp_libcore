local sobj = stp.obj
local snet = stp.obj.net

local NETABLE = sobj.BeginTrait("stp.obj.net.Networkable")
local NETREV = sobj.BeginTrait("stp.obj.net.NetworkableRev")
local NETCOMP = sobj.BeginTrait("stp.obj.net.NetworkableComposite")

NETABLE.IsNetworkable = true
NETREV.IsNetworkable = true
NETABLE.IsNetworkableFwd = true
NETREV.IsNetworkableRev = true
NETCOMP.IsNetworkableComp = true



sobj.MakeSubobjectStorable(NETABLE, "Network")
sobj.MakeSubobjectStorable(NETREV, "NetworkRev")

sobj.MakeSubobjectContainer(NETCOMP, "Network")
sobj.MakeSubobjectContainer(NETCOMP, "NetworkRev")

function NETABLE:NetGetRestrictor()
    return self.__net_restrictor
end

function NETABLE:NetSetRestrictor(restrictor)
    snet.restrictors._Set(self, restrictor)
    self.__net_restrictor = restrictor
end

if SERVER then
    sobj.MarkAbstract(NETABLE, "NetGetRecipients", "function")
end

snet.Networkable = sobj.Register(NETABLE)
snet.NetworkableRev = sobj.Register(NETREV)


NETABLE(NETCOMP)
snet.NetworkableComposite = sobj.Register(NETCOMP)

function snet.MakeRecipientEveryone(meta)
    sobj.CheckNotFullyRegistered(meta)

    if CLIENT then return end

    function meta:NetGetRecipients(recip)
        recip:AddAllPlayers()
    end
end