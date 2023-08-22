local LIB = stp.obj

local INITABLE = LIB.BeginTrait("stp.obj.Initializable")

LIB.HookDefine(INITABLE, "Init")
LIB.HookDefine(INITABLE, "PostInit")


LIB.Register(INITABLE)
LIB.Initializable = INITABLE


local REMOVABLE = LIB.BeginTrait("stp.obj.Removable")
INITABLE(REMOVABLE)

LIB.HookDefine(REMOVABLE, "OnPreRemove")
LIB.HookDefine(REMOVABLE, "OnRemove")

LIB.Register(REMOVABLE)
LIB.Removable = REMOVABLE

local INST = LIB.BeginTrait("stp.obj.Instantiatable")
REMOVABLE(INST)

function INST.Create(args)
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


LIB.Register(INST)
LIB.Instantiatable = INST