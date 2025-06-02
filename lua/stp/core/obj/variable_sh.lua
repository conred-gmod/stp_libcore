local sobj = stp.obj

local VAR = sobj.BeginTrait("stp.obj.Variable")
local VARCONT = sobj.BeginTrait("stp.obj.VariableContainer")

sobj.MakeSubobjectStorable(VAR, "Variable")
sobj.MakeSubobjectContainer(VARCONT, "Variable")

sobj.MarkAbstract(VAR, "VariableInit", "function")
sobj.MarkAbstract(VAR, "VariableGet", "function")
sobj.MarkAbstract(VAR, "VariableSet", "function")

sobj.HookDefine(VAR, "VariableOnSet")

sobj.Variable = sobj.Register(VAR)
sobj.VariableContainer = sobj.Register(VARCONT)

local VARF = sobj.BeginTrait("stp.obj.VariableField")

function VARF:VariableInit(param)
    if param == nil then return nil end
    return param.VarValue
end

function VARF:VariableGet()
    return self._var_value
end

function VARF:VariableSet(val)
    self:VariableOnSet(self._var_value, val)
    self._var_value = val
end

sobj.VariableField = sobj.Register(VARF)

function sobj.MakeAttached(accessor)
    return function(meta)
        local parentmeta = meta.OwnerType
        if parentmeta == nil then
            stp.Error(meta," is not a 'stp.obj.NestedObject'")
        end
    
        sobj.CheckNotFullyRegistered(meta)
        sobj.CheckNotFullyRegistered(parentmeta)

        sobj.Instance(meta)
        sobj.Instance(parentmeta)
    
        local typename = meta.TypeName
        local keyname = "__attached_"..typename
    
        sobj.HookDefine(meta, "FillInitParams")
    
        sobj.HookAdd(parentmeta, "Init", "attach_"..typename, function(self, params)
            local attachparams = {}
            meta.FillInitParams(params, attachparams)
            attachparams.Owner = self
    
            local obj = meta:Create(attachparams)

    
            self[keyname] = obj
        end)

        sobj.HookAdd(meta, "Init", "init_"..typename, function(self, params)
            self.Owner = params.Owner
        end)
    
        sobj.HookAdd(parentmeta, "OnRemove", "remove_"..typename, function(self)
            local obj = self[keyname]
            assert(IsValid(obj), typename.." is not valid at owner remove time")
    
            obj:Remove(true) -- Cascaded?
    
            self[keyname] = nil 
        end)

        parentmeta[accessor] = function(self) 
            return self[keyname]
        end
    end
end

function sobj.MakeVariableAttached(varmeta, parentmeta)
    local parentmeta = parentmeta or varmeta.OwnerType
    if parentmeta == nil then
        stp.Error("Attempt to attach variable type ",varmeta,", but attachment target found ",
            "(both second argument of `stp.obj.MakeVariableAttached` and `.OwnerType` of variable type are nil)")
    end

    sobj.CheckNotFullyRegistered(parentmeta)

    local vartyname = varmeta.TypeName

    local accessorname = "__Get"..vartyname
    sobj.MakeAttached(accessorname)(varmeta)

    sobj.HookAdd(varmeta, "Init", "stp.obj.MakeVariableAttached", function(self, param)
        self:VariableSet(self:VariableInit(param.VarInit))
        self.Owner.SubobjVariable:SetByName(vartyname, self)
    end)

    sobj.HookAdd(varmeta, "OnRemove", "stp.obj.MakeVariableAttached", function(self)
        self.Owner.SubobjVariable:SetByName(vartyname, nil)
    end)

    parentmeta:RegisterSubobjVariable(vartyname)
end

function sobj.MakeVariableField(meta)
    VARF(meta)
    sobj.MakeVariableAttached(meta)
end

function sobj.MakeVariableAccessors(getter, setter, listener)
    if getter == false then getter = nil end
    if setter == false then setter = nil end
    if listener == false then listener = nil end

    return function(varmeta)
        local parentmeta = varmeta.OwnerType
        if parentmeta == nil then
            stp.Error(varmeta," not implements `stp.obj.NestedObject`")
        end
        sobj.CheckNotFullyRegistered(parentmeta)
        local vartyname = varmeta.TypeName

        if getter ~= nil then
            parentmeta[getter] = function(self)
                return self.SubobjVariable.ByName[vartyname]:VariableGet()
            end
        end

        if setter ~= nil then
            parentmeta[setter] = function(self, value)
                self.SubobjVariable.ByName[vartyname]:VariableSet(value)
            end
        end

        if listener ~= nil then
            sobj.MarkAbstract(parentmeta, listener, "function")

            sobj.HookAdd(varmeta, "VariableOnSet", "listener_"..parentmeta.TypeName, 
                function(self, old, new)
                    local owner = self.Owner
                    owner[listener](owner, old, new)
                end)
        end
    end
end

function sobj.VariableRequireInit(ctorkey)
    return function(varmeta)
        function varmeta:VariableInit(param)
            if ctorkey == nil then ctorkey = self.PostfixName end

            local val = param[ctorkey]
            if val == nil then
                stp.Error("Variable '",self,"' not initialized: constructor key '",ctorkey,"' missing")
            end

            return val
        end
    end
end

function sobj.VariableDefault(default)
    return function(varmeta)
        function varmeta:VariableInit(_)
            return default
        end
    end
end