Пример работы с низкоуровневым API (в большинстве случаев пользоваться им напрямую не нужно)
```lua
-- namespace stp.rp
local librp = stp.rp

local libo = stp.obj
local libdb = stp.db

librp.Database = libdb.SqliteDatabase("stp.rp.production")
```


```lua
-- namespace stp.rp
local librp = stp.rp

local libo = stp.obj
local libdb = stp.db

-- Assume 'stp.rp.Player' is defined elsewhere
local PLY = libo.BeginObject("stp.rp.Player.Data")
libo.ApplyMany(PLY,
        libdb.MakeTableObject(PLY.TypeName, "0.1") -- Table Name, Version
    )

libo.ConstructNestedType(PLY, "SteamID",
        libdb.MakeVariable(libdb.Schema.String),
        libdb.MakePrimaryKey
    )

libo.ConstructNestedType(PLY, "TotalTime",
        libdb.MakeVariable(libdb.Schema.Number),
        libdb.VariableConstrained(
            libdb.Constraint.Compare(libdb.Constraint.CMP_GREATER_EQUALS, 0)
            ),
        
        libo.VariableDefault(0)
    )

libo.ConstructNestedType(PLY, "LastJoinTime",
        libdb.MakeVariable(libdb.Schema.Number),
        libdb.VariableConstrained(
            libdb.Constraint.Compare(stp.CMP.GREATER_EQUALS, 0)
            ),

        libdb.VariableNullable, libo.VariableDefaultNull
    )


libo.Register(PLY)
librp.Player.Data = PLY

local Query_RemoveOldPlayers
do
    local q = libdb.Query(libdb.QUERY_RESULT.SINGLE)
    local minLastJoin = q:Parameter("min_last_join_time", libdb.Schema.Number)

    local plys = q:From(PLY)
    local lastjoin = plys:Key(PLY.DB_SCHEMA.LastJoinTime)

    local old_plys = plys:Filter(
        libdb.Expr.Compare(lastjoin, stp.CMP.LESS, minLastJoin)
    )

    local removed_plys = old_plys:Remove()

    local removed_cnt = q:Result("removed_count", libdb.Schema.Number)
    removed_cnt:Set(libdb.Expr.Count(removed_plys))

    Query_RemoveOldPlayers = q:Build()
    -- Resulting query:
    --[[
        DELETE FROM {current PLY table name} AS ply
            WHERE ply.LastJoinTime < {min_last_join_time}
            RETURNING count(*) AS removed_count

    ]]
end

concommand.Add("stprp_player_remove_old", function(_,_,_,args)
    local time = time_toseconds(args[1]) -- (sample function name)
    if time == nil then
        print("Invalid time",args[1])
        return
    end

    local removed = Query_RemoveOldPlayers:RunSingle(librp.Database, { min_last_join_time = time })
        .removed_count

    print("Removed",removed,"players")
end)

gameevent.Listen("player_connect")
hook.Add("player_connect", "stp.rp.LoadOrCreatePlayer", function(data)
    if data.bot ~= 0 then return end
    local steamid = data.networkid
    local ply = Entity(data.index + 1)

    local plydata = PLY.Query_LoadAllByKey:RunSingle(librp.Database, steamid)
    if plydata == nil then
        plydata = PLY.Query_Create:RunSingle(librp.Database, {
            SteamID = steamid
        })
    end

    plydata.NoUnloadOnDisconnect = false

    plydata.LastJoinTime = os.time()
    plydata:Store()

    plydata.Entity = ply
    ply.stpRP_Data = plydata
end)

local function TryUnloadPlayer(plydata, is_disconnect)
    if not is_disconnect and IsValid(plydata.Entity) then return end -- Engine Player is active
    if is_disconnect and plydata.NoUnloadOnDisconnect then return end

    plydata:Unload()
end

hook.Add("PlayerDisconnected", "stp.rp.UnloadDisconnectedPlayer", function(ply)
    local data = ply.stpRP_Data
    if data == nil then return end -- Bot, probably

    plydata.TotalTime = plydata.TotalTime + os.difftime(os.time() - plydata.LastJoinTime)
    plydata:Store()

    TryUnloadPlayer(plydata, true)
end)

local function DoSomeStuffWithUnloadedPlayer(steamid)
    local ply = PLY.Query_LoadAllByKey:RunSingle(librp.Database, steamid)
    if ply == nil then return end
    ply.NoUnloadOnDisconnect = true -- So if player connects and disconnects, object is not unloaded

    -- Work with `ply`. You can ever use timers and other async execution.

    -- Simulate some work
    timer.Simple(20, function()
        TryUnloadPlayer(plydata, false)
    end)
end

```