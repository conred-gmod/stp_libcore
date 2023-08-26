local function DoLoad()
    AddCSLuaFile("stp/core/_include.lua")
    include("stp/core/_include.lua")
end

DoLoad()
concommand.Add("stplib_reload_full", function()
    print("==== Full reload begin")
    DoLoad()
    print("==== Full reload end")
end)