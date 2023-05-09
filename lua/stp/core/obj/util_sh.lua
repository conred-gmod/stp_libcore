local LIB = stp.obj

function LIB.ApplyMany(target, ...)
    for _, fn in ipairs({...}) do
        fn(target)
    end

    return target
end

LIB.MergerRegisterArray("CallInOrder_Member", function(meta, key, values)
    local fns = {} -- Hope this will get inlined
    for i, pair in ipairs(values) do
        fns = pair.Value
    end

    meta[key] = function(self, ...)
        for _, fn in ipairs(fns) do
            fn(self, ...)
        end
    end
end)