local check_ty = STPLib.CheckType

local LIB = STPLib.ObjNet

local Parents = Parents or {}
local Children = Children or {}
local Unparented = Unparented or {}

LIB.Parents     = Parents
LIB.Children    = Children
LIB.Unparented  = Unparented

function LIB.SetParent(child, parent)
    check_ty(child, "child", "table")
    check_ty(parent, "parent", {"table","nil"})

    local child_id = child:Net_GetId()
    local parent_old_id = Parents[child_id]
    local parent_id = parent and parent:Net_GetId() or nil


    if parent_old_id == parent_id then return end

    if parent_old_id == nil --[[and parent_id ~= nil]] then
        Unparented[child_id] = nil
        Parents[child_id] = parent_id
        Children[parent_id][child_id] = true

    elseif parent_id == nil --[[and parent_old_id ~= nil]] then
        Unparented[child_id] = true
        Parents[child_id] = nil
        Children[parent_old_id][child_id] = nil
    else --[[if parent_id ~= nil and parent_old_id ~= nil then]]
        Parents[child_id] = parent_id

        Children[parent_old_id][child_id] = nil
        Children[parent_id][child_id] = nil
    end
end

hook.Add("STPLib.ObjNet.OnRegistered", "___STPLib.ObjNet.Parenting", function(obj)
    if not LIB.IsNetworkable(obj) then return end

    local obj_id = obj:Net_GetId()
    Unparented[obj_id] = true
    Children[obj_id] = {}
end)

hook.Add("STPLib.Obj.OnPostRemoved", "aaaab___STPLib.ObjNet.Parenting", function(obj, cascaded)
    if not LIB.IsNetworkable(obj) then return end

    local obj_id = obj:Net_GetId()

    if not cascaded then
        local parent_id = Parents[obj_id]
        if parent_id ~= nil then
            Children[parent_id][obj_id] = nil
        end
    end

    Unparented[obj_id] = nil
    Parents[obj_id] = nil

    Children[obj_id] = nil
end)