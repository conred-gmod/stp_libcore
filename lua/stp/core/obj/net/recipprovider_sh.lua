local sobj = stp.obj
local snet = stp.obj.net
local check_ty = stp.CheckType

local RPR = sobj.BeginTrait("stp.obj.net.RecipientProivder") 
sobj.ApplyMany(RPR,
    sobj.Initializable,
    snet.Networkable
)

if SERVER then
    sobj.HookAdd(RPR, "Init", RPR.TypeName, function(self)
        self._recipientProviders = {}
    end)

    function RPR:NetGetRecipients(recip)
        for _, fn in pairs(self._recipientProviders) do
            fn(self, recip)
        end
    end

    function RPR:AddRecipientProvider(name, fn)
        check_ty(name, "name", "string")
        check_ty(fn, "fn", "function")

        self._recipientProviders[name] = fn
    end

    function RPR:RemoveRecipientProvider(name)
        check_ty(name, "name", "string")

        self._recipientProviders[name] = nil
    end
end

sobj.Register(RPR)
snet.RecipientProivder = RPR