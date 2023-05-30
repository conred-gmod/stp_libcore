local LIB = stp.obj

local VAR = LIB.BeginTrait("stp.obj.Variable")
local VARCONT = LIB.BeginTrait("stp.obj.VariableContainer")

LIB.MakeSubobjectStorable(VAR, "Variable")
LIB.MakeSubobjectContainer(VARCONT, "Variable")

LIB.MarkAbstract(VAR, "VariableInit", "function")
LIB.MarkAbstract(VAR, "VariableGet", "function")
LIB.MarkAbstract(VAR, "VariableSet", "function")

LIB.HookDefine(VAR, "VariableOnSet")

LIB.Register(VAR)
LIB.Register(VARCONT)
LIB.Variable = Var
LIB.VariableContainer = VARCONT