local sobj = stp.obj

local INITABLE = sobj.BeginTrait("stp.obj.Initializable")

sobj.HookDefine(INITABLE, "Init")
sobj.HookDefine(INITABLE, "PostInit")

sobj.Initializable = sobj.Register(INITABLE)


local REMOVABLE = sobj.BeginTrait("stp.obj.Removable")
INITABLE(REMOVABLE)

sobj.HookDefine(REMOVABLE, "OnPreRemove")
sobj.HookDefine(REMOVABLE, "OnRemove")

sobj.Removable = sobj.Register(REMOVABLE)

local INST = sobj.BeginTrait("stp.obj.Instantiatable")
REMOVABLE(INST)

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


sobj.Instantiatable = sobj.Register(INST)