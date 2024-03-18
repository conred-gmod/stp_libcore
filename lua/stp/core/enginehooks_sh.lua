local libn = stp.obj.net 

-- Add a signle hook handler here if specific order of handler execution is necessary:
--[[
    hook.Add("OnExample", "stp.DoAllStuff", function()
        stp.module1._OnExampleHandler()
        stp.module2._OnExampleHandler() -- Depends on results of previous handler's actions
        stp.module3._OnExampleHandler() -- Depends on results of previous handlers' actions
    end)
]] 
--
-- Do not add a handler for a single module, do that in module's file (or folder) instead.

hook.Add("Tick", "stp.DoAllStuff", function()
    if SERVER then
        libn.awareness._Update()
    end
    libn._TransmitAll()
end)