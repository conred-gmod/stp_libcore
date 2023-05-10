local LIB = stp.obj

function LIB.MakeManager(item, manager, desc)
    LIB.CheckNotFullyRegistered(item)
    LIB.CheckNotFullyRegistered(manager)
    local data = { Item = item, Manager = manager, Desc = desc }

    local isg = desc.ItemSg
    local ipl = desc.ItemPl
    local msg = desc.ManagerSg

    local GenerateKey = desc.GenerateKey

    local key_mixin = "___mixin_manager_"..isg

    LIB.Removable(item)
    LIB.Initializable(manager)

    local function makehook(prefix)
        LIB.MergablesDeclare(item, prefix..isg, "CallInOrder")
        LIB.MergablesDeclare(manager, prefix..isg, "CallInOrder")
    end

    makehook("OnPreRegistered")
    makehook("OnPostRegistered")
    makehook("OnPreUnregistered")
    makehook("OnPostUnregistered")

    LIB.MergablesAdd(item, "Init", key_mixin, "CallInOrder", function(self, _)
        self[key_mixin] = {
            Key = nil,
            Manager = nil
        }
    end)

    LIB.MergablesAdd(manager, "Init", key_mixin, "CallInOrder", function(self, _)
        self[key_mixin] = {
            Items = {},
        }
    end)

    manager["Register"..isg] = function(self, item, ...)
        local existing_key = item[key_mixin].Key 
        if existing_key ~= nil then return existing_key end

        local key = GenerateKey(self, item, ...)

        self["OnPreRegistered"..isg](self, item, key, ...)
        item["OnPreRegistered"..isg](item, self, key, ...)

        self[key_mixin].Items[key] = item
        item[key_mixin] = {
            Key = key,
            Manager = self
        }

        item["OnPostRegistered"..isg](item, self, key, ...)
        self["OnPostRegistered"..isg](self, item, key, ...)

        return key
    end

    manager["Unregister"..isg.."ByKey"] = function(self, key)
        local data = self[key_mixin]

        local item = data.Items[key]
        if item == nil then return end

        self["OnPreUnregistered"..isg](self, item, key)
        item["OnPreUnregistered"..isg](item, self, key)

        data.Items[key] = nil

        item["OnPostUnregistered"..isg](item, self, key)
        self["OnPostUnregistered"..isg](self, item, key)
    end

    manager["Unregister"..isg] = function(self, item)
        self["Unregister"..isg.."ByKey"](self, item[key_mixin].Key)
    end

    manager["UnregisterAll"..ipl] = function(self)
        local items = self[key_mixin].Items

        for key, item in pairs(items) do     
            self["OnPreUnregistered"..isg](self, item, key)
            item["OnPreUnregistered"..isg](item, self, key)

            item[key_mixin] = {}
        end

        self[key_mixin].Items = {}

        for key, item in pairs(items) do     
            self["OnPostUnregistered"..isg](self, item, key)
            item["OnPostUnregistered"..isg](item, self, key)
        end
    end

    manager["GetAll"..ipl] = function(self)
        return self[key_mixin].Items
    end

    manager["Get"..isg.."Key"] = function(self, item)
        return item[key_mixin].Key
    end

    manager["Get"..isg.."ByKey"] = function(self, key)
        return self[key_mixin].Items[key]
    end

    item["GetUsed"..msg] = function(self)
        return self[key_mixin].Manager
    end

    item["Get"..isg.."Key"] = function(self)
        return self[key_mixin].Key
    end

    return data
end