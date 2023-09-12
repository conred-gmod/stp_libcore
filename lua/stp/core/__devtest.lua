-- Add test code into this file. Clear this file in release commits.

local libo = stp.obj

print("---- __devtest.lua start")

local META = libo.BeginTrait("testmeta")
do
    print("---", META, META.__index == META, debug.getmetatable(META) == META)
    PrintTable(META)
    print("---")
    print("META.NotExists = ", META.NotExists)
end

libo.Register(META)

print("---- __devtest.lua end")