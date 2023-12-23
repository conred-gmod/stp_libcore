local libo = stp.obj

local VAR = libo.BeginTrait("stp.obj.Variable")
local VARCONT = libo.BeginTrait("stp.obj.VariableContainer")

libo.MakeSubobjectStorable(VAR, "Variable")
libo.MakeSubobjectContainer(VARCONT, "Variable")

libo.MarkAbstract(VAR, "VariableInit", "function")
libo.MarkAbstract(VAR, "VariableGet", "function")
libo.MarkAbstract(VAR, "VariableSet", "function")

libo.HookDefine(VAR, "VariableOnSet")

libo.Register(VAR)
libo.Register(VARCONT)
libo.Variable = VAR
libo.VariableContainer = VARCONT

local VARF = libo.BeginTrait("stp.obj.VariableField")

function VARF:VariableInit(param)
    debug.Trace()
    print("VARF:VariableInit", table.ToString(param))
    return param.VarValue
end

function VARF:VariableGet()
    return self._var_value
end

function VARF:VariableSet(val)
    debug.Trace()
    print(self,"VariableSet",val)

    self:VariableOnSet(self._var_value, val)
    self._var_value = val
end

libo.Register(VARF)
libo.VariableField = VARF

function libo.MakeAttached(accessor)
    return function(meta)
        local parentmeta = meta.OwnerType
        if parentmeta == nil then
            stp.Error(meta," is not a 'stp.obj.NestedObject'")
        end
    
        libo.CheckNotFullyRegistered(meta)
        libo.CheckNotFullyRegistered(parentmeta)

        libo.Instantiatable(meta)
        libo.Instantiatable(parentmeta)
    
        local typename = meta.TypeName
        local keyname = "__attached_"..typename
    
        libo.HookDefine(meta, "FillInitParams")
    
        libo.HookAdd(parentmeta, "Init", "attach_"..typename, function(self, params)
            local attachparams = {}
            meta.FillInitParams(params, attachparams)
            attachparams.Owner = self
    
            local obj = meta:Create(attachparams)

    
            self[keyname] = obj
        end)

        libo.HookAdd(meta, "Init", "init_"..typename, function(self, params)
            self.Owner = params.Owner
        end)
    
        libo.HookAdd(parentmeta, "OnRemove", "remove_"..typename, function(self)
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

function libo.MakeVariableAttached(varmeta, parentmeta)
    local parentmeta = parentmeta or varmeta.OwnerType
    if parentmeta == nil then
        stp.Error("Attempt to attach variable type ",varmeta,", but attachment target found ",
            "(both second argument of `stp.obj.MakeVariableAttached` and `.OwnerType` of variable type are nil)")
    end

    libo.CheckNotFullyRegistered(parentmeta)

    local vartyname = varmeta.TypeName

    local accessorname = "__Get"..vartyname
    libo.MakeAttached(accessorname)(varmeta)
    
    libo.HookAdd(varmeta, "FillInitParams", "stp.obj.MakeVariableAttached", function(owner_params, attach_params)
        attach_params.VarInit = owner_params
    end)


    libo.HookAdd(varmeta, "Init", "stp.obj.MakeVariableAttached", function(self, param)    
        print(self, "Attached variable init")
        self:VariableSet(self:VariableInit(param.VarInit))
        self.Owner.SubobjVariable:SetByName(vartyname, self)
    end)

    -- TODO: is it correct that 'parentmeta' is used here and not 'varmeta'?
    libo.HookAdd(parentmeta, "OnRemove", "stp.obj.MakeVariableAttached", function(self)
        self.Owner.SubobjVariable:SetByName(vartyname, nil)
    end)

    parentmeta:RegisterSubobjVariable(vartyname)
end

function libo.MakeVariableField(meta)
    VARF(meta)
    libo.MakeVariableAttached(meta)
end

function libo.MakeVariableAccessors(getter, setter, listener)
    if getter == false then getter = nil end
    if setter == false then setter = nil end
    if listener == false then listener = nil end

    return function(varmeta)
        local parentmeta = varmeta.OwnerType
        if parentmeta == nil then
            stp.Error(varmeta," not implements `stp.obj.NestedObject`")
        end
        libo.CheckNotFullyRegistered(parentmeta)
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
            libo.MarkAbstract(parentmeta, listener, "function")

            libo.HookAdd(varmeta, "VariableOnSet", "listener_"..parentmeta.TypeName, 
                function(self, old, new)
                    local owner = self.Owner
                    owner[listener](owner, old, new)
                end)
        end
    end
end

function libo.VariableRequireInit(ctorkey)
    return function(varmeta)
        function varmeta:VariableInit(param)
            debug.Trace()
            if ctorkey == nil then ctorkey = self.PostfixName end

            local val = param[ctorkey]
            if val == nil then
                stp.Error("Variable '",self,"' not initialized: constructor key '",ctorkey,"' missing")
            end

            return val
        end
    end
end

function libo.VariableDefault(default)
    return function(varmeta)
        function varmeta:VariableInit(_)
            debug.Trace()
            return default
        end
    end
end