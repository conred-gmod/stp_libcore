local checkty = STPLib.CheckType

---------

local Lib = Lib or {}
STPLib.GObj = Lib

local WEAKMETA = {
    __mode = "v"
}

--=======================================
-- -- -- Interface Type

Lib.SIDE = {
    BIDIR = 0,
    IN = 1,
    OUT = 2
}

local IfTypes = IfTypes or {}
Lib.Types = IfTypes

-- TODO: handle hotreload correctly
function Lib.RegisterType(ty)
    checkty(ty, "ty", "table")

    local typename = checkty(ty.typename, "ty.typename", "string")

    ty.sides_enum = {}

    for side_id, side in pairs(ty.sides) do
        table.insert(sides_enum, side_id)

        -- TODO
        checkty(side.allow_many, "ty.sides[<key>].allow_many", "bool")
        checkty(side.track_connected, "ty.sides[<key>].track_connected", "bool")
    end

    if ty.default_side ~= nil then
        if ty.sides[ty.default_side] == nil then
            STPLib.Error("Interface type '", typename, "' has non-existant default side '",ty.default_side,"'")
        end
    end

    IfTypes[typename] = ty
end

--=======================================
-- -- -- Component Type

local CompTypes = CompTypes or {}
Lib.ComponentTypes = CompTypes

local COMP = COMP or {}
COMP.__index = COMP

function Lib.RegisterComponent(meta)
    checkty(meta, "meta", "table")
    local typename = checkty(meta.Type, "meta.Type", "string")

    assert(meta.__index == nil, "Currently custom component index metafunctions are not supported!")
    meta.__index = COMP

    CompTypes[typename] = meta 
end

function Lib.CreateComponent(type, params)
    checkty(type, "type", "string")
    checkty(params, "params", "table")

    local meta = CompTypes[type]
    if meta == nil then
        STPLib.Error("Attempt to create component with invalid type '",type,"'")
    end

    local comp = setmetatable({
        __isValid = false,
        Interfaces = {}
    }, meta)

    comp.__isValid = true
    comp:Init(params)

    return comp
end

function COMP:Init(params) end

function COMP:IsValid() return self.__isValid end

function COMP:Remove()
    assert(self.__isValid, "Attempt to remove invalid component!")
    
    self:PreRemove()

    for _, iface in pairs(self.Interfaces) do
        iface:_Remove(true)
    end

    self.__isValid = false
end

function COMP:PreRemove() end

--=======================================
-- -- -- Interface (with related component API)

local IFACE = IFACE or {}
IFACE.__index = IFACE

function COMP:AddInterface(params)
    assert(self.__isValid, "Attempt to add interface to invalid component!")
    
    checkty(params, "params", "table")

    local name = checkty(params.name, "params.name", "string")
    if self.Interfaces[name] ~= nil then
        STPLib.Error("Attempt to add interface '",name,"' that is already added")
    end
    
    local typename = checkty(params.type, "params.type", "string")
    local type = IfTypes[typename]
    if type == nil then STPLib.Error("Attempt to create interface '",name,"' with invalid type '",typename,"'") end

    local side = params.side
    if side == nil or type.sides[side] == nil then
        STPLib.Error("Attempt to create interface '",name,"' with invalid side '",side,"'")
    end

    local data = params.data


    local iface = setmetatable({
        TypeName = typename,
        _type = type,
        Side = side,
        _owner = setmetatable({ val = self}, WEAKMETA),
        Data = data,
        _network = nil,
        _isValid = true
    }, IFACE)

    self.Interfaces[name] = iface
    self[name] = iface
end

function IFACE:GetOwner()
    local owner = self._owner.val

    if not IsValid(owner) then
        return nil 
    else
        return owner
    end
end

function IFACE:IsValid()
    return self:GetOwner() ~= nil and self._isValid
end

function IFACE:_Remove(component_removed)
    assert(self:IsValid(), "Attempt to remove invalid component interface")

    self:Detach()

    if not component_removed then
        -- By assert at start of the function we guarantee that GetOwner return non-nil
        local owner = self:GetOwner()

        owner.Interface[self.Name] = nil
        owner[self.Name] = nil
    end

    self._isValid = false
    self._owner.val = nil -- To help GC
    self.Data = nil -- Also to help GC
end

function IFACE:Remove() self:_Remove(false) end

function IFACE:OnSelfAttached() end
function IFACE:OnSelfPreDetached() end

function IFACE:OnOtherAttached(iface) end
function IFACE:OnOtherPreDetached(iface) end

--=======================================
-- -- -- Network (with related interface API)

local NET = NET or {}
NET.__index = NET

function Lib.CreateNetwork(iftype)
    checkty(iftype, "iftype", "string")

    local type = IfTypes[iftype]
    if type == nil then
        STPlib.Error("Attempt to create network with invalid type '",type,"'")
    end

    local netw = setmetatable({
        TypeName = iftype,
        _type = type,
        _isValid = true,
        _connected = {}
    }, NET)
end

function NET:IsValid() return self._isValid end
function NET:Remove()    
    for _, side in ipairs(self._type.sides_enum) do
        local conn = self._connected[side]
        for _, iface in ipairs(conn or {}) do
            self:Disconnect(iface)
        end
    end

    self._isValid = false
    self._connected = nil -- Help the GC
end





function NET:CanConnect(val)
    checkty(val, "val", {"string","table"})

    if isstring(val) then
        val = IfTypes[val]
        assert(val ~= nil, "Unknown interface type checked")
    end

    local meta = getmetatable(val)

    if meta == IFACE then
        return self:_CanConnectInterface(val)
    elseif val.typename ~= nil and IfTypes[val.typename] == val then
        return CanConnectType(self.TypeName, val)
    else
        STPLib.Error("Unsupported type passed")
    end
end

local function CanConnectType(selfty, ty)
    if istable(ty) then ty = ty.typename end

    if ty ~= selfty then
        return false, "Incompatible types: required '"..selfty.."', got '"..ty.."'"
    else
        return true
    end
end

function NET:_CanConnectInterface(iface)
    if not iface:IsValid() then 
        return false, "Interface is not valid"
    end

    local ty = iface.TypeName

    local ok, error = CanConnectType(self.TypeName, ty)
    if not ok then return false, error end

    local side = iface.Side

    if not self._type.sides[side].allow_many then
        if not table.IsEmpty(self._connected[side]) then
            return false, "Only 0 or 1 interfaces of this side may be in the network"
        end 
    end

    if iface._network ~= nil then
        return false, "Interface already connected"
    end

    return true
end

function NET:OnConnected(iface) end
function NET:OnPreDisconnected(iface) end

function NET:Connect(iface)
    checkty(iface, "iface", "table")
    local ok, error = self:_CanConnectInterface(iface)
    if not ok then return false, error end

    local side = iface.Side
    local sidedesc = self._type.sides[side]

    if sidedesc.track_connected then
        table.insert(self._connected[side], iface)
    end
    iface._network = self

    if sidedesc.can_cause_callbacks then
        self:_OnConnected(iface)
    end

    return true
end

function NET:Disconnect(iface)
    checkty(iface, "iface", "table")
    assert(iface:IsValid(), "Interface is not valid")
    assert(self:_CanConnectType(iface.TypeName))

    local side = iface.side
    local sidedesc = self._type.sides[side]

    local idx

    if sidedesc.track_connected then
        idx = table.SeqFindValue(self._connected[side], iface)
        if idx == nil then
            STPLib.Error("Attempt to remove interface '",iface,"' not connected to this network")
        end
    end

    if sidedesc.can_cause_callbacks then
        self:_OnPreDisconnected(iface)
    end

    if sidedesc.track_connected then
        table.remove(self._connected[side], idx)
    end
    iface._network = nil
end

function IFACE:SetNetwork(net)
    check_ty(net, "net", {"table","nil"})

    if self._network == net then return end

    if self._network ~= nil then
        self._network:Disconnect(self)
    end
    if net ~= nil then
        return net:Connect(iface)
    else
        return true
    end
end

function IFACE:GetNetwork()
    return net
end

function NET:_OnConnected(iface)
    for _, side in ipairs(self._type.sides_enum) do
        local sidedesc = self._type.sides[side]
        if not sidedesc.can_receive_callbacks then continue end

        for _, recv in ipairs(self._connected[side]) do
            recv:_OnAttached(iface)
        end
        
    end

    self:OnConnected(iface)
end

function IFACE:_OnAttached(other)
    if other == self then
        self:OnSelfAttached()
    else
        self:OnOtherAttached(other)
    end
end

function NET:_OnPreDisconnected(iface)
    self:OnPreDisconnected(iface)

    for _, side in ipairs(self._type.sides_enum) do
        local sidedesc = self._type.sides[side]
        if not sidedesc.can_receive_callbacks then continue end
        
        for _, recv in ipairs(self._connected[side]) do
            recv:_OnPreDetached(iface)
        end
        
    end
end

function IFACE:_OnPreDetached(other)
    if other == self then
        self:OnSelfPreDetached()
    else
        self:OnOtherPreDetached(other)
    end
end

function NET:GetConnected(side)
    return self._connected[side]
end

function NET:GetConnectedSingle(side)
    local sidedesc = self._types.sides[side]

    if not sidedesc.allow_manyand and sidedesc.track_connected then
        return self._connected[side][1]
    else
        return nil
    end 
end

function IFACE:GetAttached(side)
    if self._network == nil and self._type.sides[side].track_connected then
        return {}
    end

    return self._network:GetConnected(side)
end

function IFACE:GetAttachedSingle(side)
    if self._network == nil then
        return nil
    end

    return self._network:GetConnectedSingle(side)
end


function IFACE:Attach(other)
    local ok, err = self:CanAttach(other)
    if not ok then return err end

    local net = Lib.CreateNetwork(self.TypeName)
    
    local err = net:Connect(self)
    if err ~= nil then return err end

    local err = net:Connect(other)
    return err
end

function IFACE:Detach()
    local err = self:SetNetwork(nil)
    assert(err ~= nil, err)
end

function IFACE:CanAttach(val)
    checkty(val, "val", {"string", "table"})

    if isstring(val) then
        val = IfTypes[val]
        assert(val ~= nil, "Unknown interface type checked")
    end

    local meta = getmetatable(val)
    if meta == IFACE then
        -- TODO
    elseif meta == NET then
        -- TODO
    elseif val.typename ~= nil and IfTypes[val.typename] == val then
        -- TODO
    else
        STPLib.Error("Unsupported type passed")
    end
end