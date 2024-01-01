# Типичные объекты

***TODO: эти примеры надо будет обновить, когда система объектов будет приведена в рабочее состояние!***


## Простой несетевой объект
```lua
if CLIENT then return end -- Или просто назовите файл yourname_sv.lua

local libo = stp.obj

local META = libo.BeginObject("your.namespace.ObjectName")
libo.ApplyMany(META,
    libo.Instantiatable -- Или libo.TrackableLocal, если нужна возможность получить по универсальному ID
)

function META:DoStuff()
    print("I store", self._data)
end

libo.HookAdd(META, "Init", "TopLevelCtorHookName", function(self, params) -- Аналог конструктора
    self._data = params.Data
end)

libo.HookAdd(META, "OnPreRemove", "TopLevelDtorName", function(self)
    print("I stored",self._data,", but now is being deleted")
end)
libo.Register(META)

--..

local function WorkWithStuff()
    local obj = META:Create({ Data = "some data"})
    print(IsValid(obj)) --> true

    obj:DoStuff() --> I store some data

    print(IsValid(obj)) --> true
    obj:Remove() --> I stored some data, but now is being deleted
    print(IsValid(obj)) --> false
end
```

## Типаж
```lua
local libyour = your.namespace
local libo = stp.obj

local META = libo.BeginTrait("your.namespace.YourTraitName")
libo.Initializable(META) -- Реализовать типаж 'stp.obj.Initializable' на '.YourTraitName'

function META:DoStuff()
    print("stuff is being done")
    self:ActuallyDoStuff()
    self:StuffIsDone()
    print("stuff is done")
end

-- Обозначить поле как абстрактное:
-- Его значение этот типаж не устанавливает, но при регистрации конечного объекта оно должно иметь указанный тип.
-- В качаестве типа можно использовать 'number', 'string, 'table' и другие - для абстрактных констант.
libo.MarkAbstract(META, "ActuallyDoStuff", "function")

-- Хуки. Как `hook.Add`/`hook.Run`, но:
--  1. вызываются как функции
--  2. не изменяются после регистрации объекта (типажа или конечного)
--  3. это нужно проверить, но они не должны оказывать влияния на производительность
--  4. возвращать значения нельзя, всегда вызываются все реализации хука.
libo.HookDefine(META, "StuffIsDone")

-- А вот так хук добавляется. 
-- META.TypeName тут равен "your.namespace.YourTraitName", в конечном типе он будет другой.
libo.HookAdd(META, "Init", META.TypeName, function(self, params)
    print("I am initialized")

    self:DoStuff()
end)

libo.Register(META)
```

## Сетевой объект

```lua
local libyour = your.namespace -- Для того, чтобы сделать тип публично доступным. Можно и не делать этого
local libo = stp.obj
local libn = stp.obj.net

local META = libo.BeginObject("your.namespace.YourObjectName")
libo.ApplyMany(META,
    libn.EasyComposite -- Для реализации типичного сетевого объекта с сетевыми переменными
    -- Your traits here
)

function META:NetGetRecipients(recip)
    recip:AddPVS(some_position)
    recip:AddPAS(other_position)
end

libo.ConstructNestedType(META, "SomeCounterName", -- Type name is `META.TypeName..".".."VariableName"`
    libo.MakeVariableField, 
    libo.MakeVariableAccessors(
        "GetSomeCounterName", 
        SERVER and "SetSomeCounterName", -- Булев тип тут эквивалентен nil - соотв. функция не будет создана
        "OnSomeCounterNameChanged")

    SERVER and libo.VariableRequireInit(), -- This will be used only on server...
    CLIENT and libo.VariableDefault(0), -- ...and this - only on client

    libn.MakeVar(libn.schema.UInt(16)),
    libn.MakeRecipientEveryone,
    libn.MakeReliable,
)

function META:OnSomeCounterNameChanged(old, new)
    print("Changed from", old, "to", new)
end

function META:Increment()
    self:SetSomeCounterName(self:GetSomeCounterName() + 1)
end

function META:Decrement()
    local val = self:GetSomeCounterName()
    if val == 0 then return false end

    self:SetSomeCounterName(val - 1)
    return true
end

libo.Register(META)
libyour.YourObjectName = META

function libyour.Create(counter_value)
    -- На клиенте сетевые объекты создавать просто так нельзя.
    -- Ф-я создания сама бросает ошибку, но тут добавил для наглядности.
    assert(SERVER) 

    assert(counter_value >= 0, "Counter value is not nonnegative")

    local obj = META:Create({
        SomeCounterName = counter_value
    })

    -- Тут объект уже в рабочем состоянии
    return obj
end
```