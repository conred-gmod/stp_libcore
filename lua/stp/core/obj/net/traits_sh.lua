local OBJ = stp.obj
local NET = stp.obj.net

local NETABLE = OBJ.BeginTrait("stp.obj.net.Networkable")
local NETREV = OBJ.BeginTrait("stp.obj.net.NetworkableRev")
local NETCOMP = OBJ.BeginTrait("stp.obj.net.NetworkableComposite")


LIB.MakeSubobjectStorable(NETABLE, "Network")
LIB.MakeSubobjectStorable(NETREV, "NetworkRev")

LIB.MakeSubobjectContainer(NETCOMP, "Network")
LIB.MakeSubobjectContainer(NETCOMP, "NetworkRev")

function NETABLE:NetGetRestrictor()
    return self.__net_restrictor
end

function NETABLE:NetSetRestrictor(restrictor)
    -- TODO: restrictor loop check

    self.__net_restrictor = restrictor
    NET.restrictor._Set(self, restrictor)
end

OBJ.MarkAbstract(NETABLE, "NetGetRecipients", "function")

OBJ.Register(NETABLE)
NET.Networkable = NETABLE
OBJ.Register(NETREV)
NET.NetworkableRev = NETREV


NETABLE(NETCOMP)
OBJ.Register(NETCOMP)
NET.NetworkableComposite = NETCOMP