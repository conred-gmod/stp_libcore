local LIB = stp.obj

local TRACK_ID_BITS = 23
LIB.TRACK_ID_BITS = TRACK_ID_BITS
local TRACK_ID_MAX = bit.lshift(1, TRACK_ID_BITS)
LIB.TRACK_ID_MAX = TRACK_ID_MAX

local TRACKABLE = LIB.BeginTrait("stp.obj.Trackable")



local TRK = LIB.BeginObject("stp.obj.Tracker")
LIB.Instantiatable(TRK)



LIB.Register(TRACKABLE)
LIB.Register(TRK)