local LIB = stp.obj

local VAR = LIB.BeginTrait("stp.obj.Variable")
local VARCONT = LIB.BeginTrait("stp.obj.VariableContainer")

LIB.MakeSubobjectStorable(VAR, "Variable")
LIB.MakeSubobjectContainer(VARCONT, "Variable")

function VAR:VariableInit()
    stp.Error("Unimplemented!")
end

function VAR:VariableGet()
    stp.Error("Unimplemented!")
end

function VAR:VariableSet(value)
    stp.Error("Unimplemented!")
end

LIB.HookDefine(VAR, "VariableOnSet")

LIB.Register(VAR)
LIB.Register(VARCONT)
LIB.Variable = Var
LIB.VariableContainer = VARCONT