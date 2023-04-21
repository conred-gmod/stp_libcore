STPLib = STPLib or {}

function STPLib.GetRealmFromFilename(filename)
    if string.EndsWith(filename, "_sv.lua") then
        return "sv"
    elseif string.EndsWith(filename, "_cl.lua") then
        return "cl"
    end

    -- xxx_sh.lua goes there
    return "sh"
end

function STPLib.IncludeFile(filename)
    local realm = STPLib.GetRealmFromFilename(filename)


    if realm ~= "sv" and SERVER then
        AddCSLuaFile(filename)
    end

    if  (realm == "sv" and SERVER) or
        (realm == "cl" and CLIENT) or
        (realm == "sh")
    then
        hook.Run("STPLib.PreFileIncluded", filename, realm)
        return include(filename)
    end
end

function STPLib.IncludeList(prefix,files)
    for i, filename in ipairs(files) do
        STPLib.IncludeFile(prefix..filename)
    end
end

function STPLib.IncludeDir(dir, recursive)
    local files, dirs = file.Find(dir.."*.lua", "LUA")
    assert(files ~= nil, "Error including directory "..dir)

    for _, filename in ipairs(files) do
        STPLib.IncludeFile(dir..filename)
    end

    if recursive then
        for _, dirname in ipairs(dirs) do
            STPLib.IncludeDir(dir..dirname.."/", true)
        end
    end
end

STPLib.IncludeList("stplib/", {
    "debug_sh.lua",
    "class_sh.lua",
    "misc_sh.lua",
    "object/core_sh.lua",
    "object/instantiantable_sh.lua",
    "object/destructable_sh.lua",
    "object/trackable_sh.lua",
    "objnet/core_sh.lua",
    "objnet/parenting_sv.lua",
    "objnet/awareness_sv.lua"
})