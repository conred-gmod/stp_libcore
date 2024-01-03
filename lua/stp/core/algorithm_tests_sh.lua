local RegTest = stp.testing.RegisterTest
local RegTestFailing = stp.testing.RegisterTestFailing
local PREFIX = "stp.core.algorithm."

RegTest(PREFIX.."tableReverseInplace.empty", function()
    local arr = {}
    table.ReverseInplace(arr)

    assert(table.IsEmpty(arr))
end)

RegTest(PREFIX.."tableReverseInplace.single", function()
    local arr = {23}
    table.ReverseInplace(arr)

    assert(table.Count(arr) == 1)
    assert(arr[1] == 23)
end)

RegTest(PREFIX.."tableReverseInplace.four", function()
    local arr = {4,8,15,16}
    table.ReverseInplace(arr)

    assert(table.Count(arr) == 4)
    assert(arr[1] == 16)
    assert(arr[2] == 15)
    assert(arr[3] == 8)
    assert(arr[4] == 4)
end)

RegTest(PREFIX.."tableReverseInplace.five", function()
    local arr = {4,8,15,16,23}
    table.ReverseInplace(arr)

    assert(table.Count(arr) == 5)
    assert(arr[1] == 23)
    assert(arr[2] == 16)
    assert(arr[3] == 15)
    assert(arr[4] == 8)
    assert(arr[5] == 4)
end)

RegTest(PREFIX.."tableSeqCount", function()
    local seqcnt = table.SeqCount

    assert(seqcnt({}) == 0)
    assert(seqcnt({nonnumeric = 108}) == 0)
    assert(seqcnt({1,2,3}) == 3)
    assert(seqcnt({nonnum = "yes", 1, 2, other = "again", 3}) == 3)
end)

RegTest(PREFIX.."tableSeqFindValue", function()
    local seqfind = table.SeqFindValue

    local array = {"first","second", nonseq = 1, "third", 4}

    assert(seqfind(array, "first") == 1)
    assert(seqfind(array, "second") == 2)
    assert(seqfind(array, "third") == 3)
    assert(seqfind(array, 4) == 4)
    assert(seqfind(array, "notexists") == nil)
end)