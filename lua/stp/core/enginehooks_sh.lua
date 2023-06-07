local libn = stp.obj.net 

hook.Add("Tick", "stp.DoAllStuff", function()
    if SERVER then
        libn.awareness._Update()
    end
    libn._TransmitAll()
end)