local libn = stp.obj.net 

hook.Add("Tick", "stp.DoAllStuff", function()
    if SERVER then
        libn.awareness._Update()
    end
    libn._TransmitAll()
end)

local queue = {}

hook.Add("PlayerInitialSpawn", "stp.NetReady", function(ply)
    queue[ply:UserID()] = true
end)

gameevent.Listen("OnRequestFullUpdate")
hook.Add("OnRequestFullUpdate", "stp.NetReady", function(data)
    local userid = data.userid
    
    if queue[userid] == nil then return end
    queue[userid] = nil

    local ply = Player(userid)
    ply.stp_NetReady = true
end)