local check_ty = STPLib.CheckType

local LIB = STPLib.ObjNet

local Result = Result

-- table(id: .Obj.ObjectId, table(ply: Player, true))
local AwarePlys = AwarePlys or {}

-- Returns false if results in no recipients
local function CheckAndFilterRecipients(recip, filter)
    local recip_cnt = recip:GetCount()
    
    if recip_cnt == 0 then return false end

    if filter == nil or filter:GetCount() == 0 then
        return true
    end

    local filter_tbl = {}
    for _, ply in ipairs(filter:GetPlayers()) do filter_tbl[ply] = true end

    for _, ply in ipairs(recip:GetPlayers()) do
        if not filter_tbl[ply] then
            recip:RemovePlayer(ply)
            recip_cnt = recip_cnt - 1
        end
    end

    return recip_cnt ~= 0
end

local function ProcessObject(oid, parent_recip, depth)
    local obj = LIB.GetObjectById(oid)

    local recip = RecipientFilter()
    obj:Net_GetRecipients(recip)

    if not CheckAndFilterRecipients(recip, parent_recip) then
        return
    end

    local newly_aware = {}

    -- TODO: find players who just became aware of obj
    local aware = AwarePlys[oid]
    for _, ply in ipairs(recip:GetPlayers()) do
        if aware[ply] then continue end

        table.insert(newly_aware, ply)
    end


    table.insert(Result, {
        obj = obj,
        aware = recip,
        newly_aware = newly_aware,
        depth = depth 
    })

    for childid, _ in pairs(LIB.Children[oid]) do
        ProcessObject(childid, recip, depth + 1)
    end
end

function LIB._AwarenessUpdate()
    Result = {}

    for oid, _ in pairs(LIB.Unparented) do
        ProcessObject(oid, nil,0)
    end
end

function LIB._AwarenessGet()
    return Result
end

function LIB._AwarenessMarkAware(oid, plys)
    local tbl = AwarePlys[oid]
    for _, ply in ipairs(plys) do
        tbl[ply] = true
    end
end

hook.Run("PlayerDisconnected", "STPLib.ObjNet.Awareness", function(ply)
    if ply:IsBot() then return end

    for _, plys in pairs(AwarePlys) do
        plys[ply] = nil
    end
end)