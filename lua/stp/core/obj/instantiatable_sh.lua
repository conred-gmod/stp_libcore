local LIB = stp.obj

local INST = LIB.BeginTrait("stp.obj.Instantiatable")

function INST.Create(args)
    local meta = self.FinalMeta
    assert(meta ~= nil)

    local instance = setmetatable({
        ___isValid = false
    }, meta)

    hook.Run("stp.obj.PreInit", instance, args)
    instance:Init(args)
    instance.___isValid = true
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
    hook.Run("stp.obj.PostRemoved", self, cascaded)
end

LIB.MergablesDeclare(INST, "Init", "CallInOrder")
LIB.MergablesDeclare(INST, "OnPreRemove", "CallInOrder")

LIB.Register(INST)