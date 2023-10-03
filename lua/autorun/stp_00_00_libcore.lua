local function DoLoad()
    AddCSLuaFile("stp/core/_include.lua")
    include("stp/core/_include.lua")
end

DoLoad()
concommand.Add("stplib_reload_full_sv", function()
    assert(SERVER)

    print("==== Full reload begin")
    DoLoad()
    if SERVER then
        for _, ply in ipairs(player.GetHumans()) do
            ply:ConCommand("stplib_reload_full_cl")
        end
    end

    print("==== Full reload end")
end)

if CLIENT then
    concommand.Add("stplib_reload_full_cl", function()
        print("==== Full reload begin")
        DoLoad()
        print("==== Full reload end")
    end)
end
