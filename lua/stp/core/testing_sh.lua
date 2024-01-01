local libtest = stp.testing
local chkty = stp.CheckType

local tests = stp.GetPersistedTable("stp.testing.Tests", {})
local TYPES = {
    SIMPLE = 1
}


function libtest.RegisterTest(name, action)
    chkty(name, "name", "string")
    chkty(action, "action", "function")

    tests[name] = { Type = TYPES.SIMPLE, Fn = action }
end

-- fn RunTestFunction(func: (fn() -> nil|errormsg: string)) -> nil | errormsg: string
local function RunTestFunction(fn)
    local _, errormsg = xpcall(function()
        local result = fn()
        if result ~= nil then
            return tostring(result)
        else
            return nil
        end
    end, function(errmsg)
        return errmsg
    end)

    return errmsg
end

local function RunTest(tbl)
    local ty = tbl.Type
    if ty == TYPES.SIMPLE then
        return RunTestFunction(tbl)
    else
        stp.Error("Unknown test type: ", ty)
    end
end

local function RunAllTests(print)
    local total_cnt = table.Count(tests)
    local successes = 0

    print("Got ",total_cnt," tests.")
    for name, tbl in SortedPairs(tests) do
        local error = RunTest(tbl)
        if error == nil then
            successes = successes + 1
            print("Test '",name,"' succeeded")
        else
            print("Test '",name,"' failed: ",error)
        end
    end
    print("Result: ",successes,"/",total_cnt," succeeded.")
end

concommand.Add("stplib_testing_runall_sv", function(ply)
    if CLIENT then return end
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    RunAllTests(MsgN)
end)

if CLIENT then
    concommand.Add("stplib_testing_runall_cl", function()
        RunAllTests(MsgN)
    end)
end