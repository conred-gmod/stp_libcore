local libo = stp.obj
local libn = stp.obj.net
local check_ty = stp.CheckType

local RPR = libo.BeginTrait("stp.obj.net.RecipientProivder") 
libo.ApplyMany(RPR,
    libo.Initializable,
    libn.Networkable
)

if SERVER then
    libo.HookAdd(RPR, "Init", RPR.TypeName, function(self)
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

libo.Register(RPR)
libn.RecipientProivder = RPR