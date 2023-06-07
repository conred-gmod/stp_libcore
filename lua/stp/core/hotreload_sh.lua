local LIB = stp

local function UnlockPersistData()
    __stp_persistdata_unlocked = true

    local HOOK_NAME = "stp.hotreload.PersistTableLock"

    hook.Add("Tick", HOOK_NAME, function()
        __stp_persistdata_unlocked = false
        hook.Remove("Tick", HOOK_NAME)
    end)
end



__stp_persistdata = __stp_persistdata or {}

UnlockPersistData()
hook.Add("OnReloaded", "stp.hotreload.PersistTableUnlock", UnlockPersistData)


function LIB.GetPersistedTable(name, default)
    assert(__stp_persistdata_unlocked, "Function called in wrong time (not before first game tick)")

    if __stp_persistdata[name] ~= nil then
        return __stp_persistdata[name]
    else
        __stp_persistdata[name] = default
        return default
    end
end

