local libaware = stp.obj.net.awareness
local librest = stp.obj.net.restrictors

-- table(obj: .Networkable, CRecipientList)
local ObserverdRecips = {}
--[[
    array({
        Object: .Networkable,
        NewlyAware: array(Players)
    })
]]
local InitRecips = {}

-- table(obj: .Networkable, table(Player, true))
local AwarePlys = stp.GetPersistedTable("stp.obj.net.awareness.AwarePlys", {})

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


local function ProcessObject(obj, restrictor, restrictor_recip)
    local recip = RecipientFilter()
    obj:NetGetRecipients(recip)

    if not CheckAndFilterRecipients(recip, restrictor_recip) then return end

    local aware = AwarePlys[obj] or {}
    local init_plys = {}
    for _, ply in ipairs(recip:GetPlayers()) do
        if not aware[ply] then
            table.insert(init_plys, ply)
        end
    end

    if not table.IsEmpty(init_plys) then
        table.insert(InitRecips, {
            Object = obj,
            NewlyAware = init_plys
        })
    end

    ObserverdRecips[obj] = recip

    for child in pairs(librest.RestrictedByThis[obj] or {}) do
        ProcessObject(child, obj, recip)
    end
end

function libaware._Update()
    ObserverdRecips = {}
    InitRecips = {}

    for obj in pairs(librest.Unrestricted) do
        ProcessObject(obj, nil, nil)
    end
end

function libaware._GetNewlyAware()
    return InitRecips
end

function libaware._GetRecipients(obj)
    return ObserverdRecips[obj]
end

function libaware._MarkAware(obj, plys)
    local aware = AwarePlys[obj]
    for _, ply in ipairs(plys) do
        aware[ply] = true
    end
end

hook.Add("PlayerDisconnected", "stp.obj.net.awareness", function(ply)
    if ply:IsBot() then return end

    for _, plys in pairs(AwarePlys) do
        plys[ply] = nil
    end
end)

hook.Add("stp.obj.PreRemove", "stp.obj.net.awareness", function(obj)
    AwarePlys[obj] = nil
end)

hook.Add("stp.obj.Tracker.OnPostTracked", "stp.obj.net.awareness", function(obj)
    AwarePlys[obj] = {}
end)