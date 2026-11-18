local targetId  = 2488
local dupeCount = 200
local totalDuped = 0
local isDuping  = true
local cycle     = 0

-- Pakai native SendPacket dari executor. Kalau nil, lu salah executor.
local SendPacket = SendPacket or (syn and syn.sendPacket) or nil
if not SendPacket then
    warn("[KAIRO] Executor lu nggak expose SendPacket. Ganti ke Synapse/Delta/Script-Ware, kontol.")
    return
end

local function jitter(base, spread)
    return base + (math.random() * spread * 2 - spread)
end

local function buildPayload(dialog, extra)
    local token = tostring(math.random(100000, 999999))
    return "action|dialog_return\ndialog_name|" .. dialog
        .. "\nid|" .. token
        .. "\n" .. extra
end

local function DropItem()
    local p = buildPayload("drop_item",
        "itemID|" .. targetId .. "\ncount|" .. dupeCount)
    SendPacket(2, p)
end

local function BuyFromRoulette()
    local p = buildPayload("nupirkti",
        "name|Roulette Wheel\npirkti_id|" .. targetId .. "\ncount|" .. dupeCount)
    SendPacket(2, p)
end

local baseDelay = 0.018
local maxDelay  = 0.120
local curDelay  = baseDelay

local function detectReject()
    return false
end

print("[KAIRO] Desync Dupe v2 nyala. Target: " .. targetId)

task.spawn(function()
    while isDuping do
        cycle = cycle + 1

        DropItem()
        task.wait(jitter(curDelay, 0.008))
        BuyFromRoulette()

        totalDuped = totalDuped + dupeCount

        if cycle % 10 == 0 then
            print("[KAIRO] Cycle " .. cycle .. " | attempted: " .. totalDuped)
        end

        if detectReject() then
            curDelay = math.min(curDelay + 0.005, maxDelay)
        else
            curDelay = math.max(baseDelay, curDelay - 0.001)
        end

        if cycle % 25 == 0 then
            task.wait(jitter(0.8, 0.2))
        else
            task.wait(jitter(0.12, 0.03))
        end
    end
end)

getgenv().StopDupe = function()
    isDuping = false
    print("[KAIRO] Stop. Total attempted: " .. totalDuped)
end