local libaware = stp.obj.net.awareness
local librest = stp.obj.net.restrictors

local Aware = {}
local NewlyAware

local function ProcessObject(obj, restrictor, restrictor_recip)
    
end

function libaware._Update()
    for obj in pairs(librest.Unrestricted) do
        ProcessObject(obj, nil, nil)
    end
end