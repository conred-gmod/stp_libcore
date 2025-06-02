local sobj = stp.obj

local INST = sobj.BeginTrait("stp.obj.Instance")

function INST:Create(args)
    local meta = self.FinalMeta
    assert(meta ~= nil)

    local instance = setmetatable({
        ___isValid = false
    }, meta)

    hook.Run("stp.obj.PreInit", instance, args)
    instance:Init(args)
    instance.___isValid = true
    instance:PostInit(args)
    hook.Run("stp.obj.PostInit",instance, args)

    return instance
end

sobj.HookDefine(INST, "Init")
sobj.HookDefine(INST, "PostInit")

function INST:IsValid()
    return self.___isValid == true
end

function INST:Remove(cascaded)
    hook.Run("stp.obj.PreRemoved", self, cascaded)
    self:OnPreRemove(cascaded)

    self.___isValid = false

    self:OnRemove(cascaded)
    hook.Run("stp.obj.PostRemoved", self, cascaded)
end

sobj.HookDefine(INST, "OnPreRemove")
sobj.HookDefine(INST, "OnRemove")


sobj.Instance = sobj.Register(INST)