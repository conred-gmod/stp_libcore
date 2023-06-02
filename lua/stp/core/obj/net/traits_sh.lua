local libo = stp.obj
local libn = stp.obj.net

local NETABLE = libo.BeginTrait("stp.obj.net.Networkable")
local NETREV = libo.BeginTrait("stp.obj.net.NetworkableRev")
local NETCOMP = libo.BeginTrait("stp.obj.net.NetworkableComposite")


LIB.MakeSubobjectStorable(NETABLE, "Network")
LIB.MakeSubobjectStorable(NETREV, "NetworkRev")

LIB.MakeSubobjectContainer(NETCOMP, "Network")
LIB.MakeSubobjectContainer(NETCOMP, "NetworkRev")

function NETABLE:NetGetRestrictor()
    return self.__net_restrictor
end

function NETABLE:NetSetRestrictor(restrictor)
    libn.restrictor._Set(self, restrictor)
    self.__net_restrictor = restrictor
end

libo.MarkAbstract(NETABLE, "NetGetRecipients", "function")

libo.Register(NETABLE)
libn.Networkable = NETABLE
libo.Register(NETREV)
libn.NetworkableRev = NETREV


NETABLE(NETCOMP)
libo.Register(NETCOMP)
libn.NetworkableComposite = NETCOMP