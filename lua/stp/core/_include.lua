stp = stp or {
    obj = {}
    trait = {}
}

local function IsLuaFile(filename)
    return string.EndsWith(filename, ".lua")
end

function stp.GetRealmFromFilename(filename)
    if not IsLuaFile(filename) then
        return nil
    elseif string.EndsWith(filename, "_sv.lua") then
        return "sv"
    elseif string.EndsWith(filename, "_cl.lua") then
        return "cl"
    end

    -- xxx_sh.lua goes there
    return "sh"
end

function stp.IncludeFile(filename)
    local realm = stp.GetRealmFromFilename(filename)
    assert(realm ~= nil, "Attempt to include non-lua file")

    if realm ~= "sv" and SERVER then
        AddCSLuaFile(filename)
    end

    if  (realm == "sv" and SERVER) or
        (realm == "cl" and CLIENT) or
        (realm == "sh")
    then
        return include(filename)
    end
end

function stp.IncludeList(prefix,files)
    for i, filename in ipairs(files) do
        stp.IncludeFile(prefix..filename)
    end
end

function stp.IncludeModules(dir, module_name)
    local files, dirs = file.Find(dir.."/*", "LUA")
    assert(files ~= nil, "Directory "..dir.."not exists")

    for _, filename in ipairs(files) do
        if IsLuaFile(filename) then
            stp.IncludeFile(dir.."/"..filename)
        end
    end

    for _, dirname in ipairs(dirs) do
        local module_file = dir.."/"..dirname.."/"..module_name

        if file.Exists(module_file, "LUA") then
            stp.IncludeFile(module_file)
        end
    end
end

stp.IncludeList("stp/core/", {
    "debug_sh.lua",

    "obj/registries_sh.lua",
    "obj/mergables_sh.lua",
    "obj/util_sh.lua",
    "obj/instantiatable_sh.lua",
    "obj/tracker_sh.lua",
})