-- =========================================================================
-- KAIRO DUPE STANDALONE v1
-- Reuse Refs dari BETARIA kalau ada. Kalau nggak, scan sendiri minimal.
-- UI sendiri, draggable, di pojok kanan atas.
-- =========================================================================

local G = (getgenv and getgenv()) or _G
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ---------------------------------------------------------------------
-- Reuse atau scan Refs
-- ---------------------------------------------------------------------
local Refs = {
    Net = nil,
    Inv = nil,
    World = nil,
}

do
    local ok, n4th = pcall(function() return G.__n4thOpus end)
    if ok and type(n4th) == "table" and type(n4th.References) == "table" then
        Refs.Net = n4th.References.Net
        Refs.Inv = n4th.References.Inv
        Refs.World = n4th.References.World
        print("[KAIRO-DUPE] Reuse Refs dari BETARIA. Net=" .. tostring(Refs.Net ~= nil)
            .. " Inv=" .. tostring(Refs.Inv ~= nil))
    end

    -- Kalau belum ada Net/Inv, scan sendiri
    if not Refs.Net or not Refs.Inv then
        print("[KAIRO-DUPE] BETARIA refs nggak ada, scan sendiri...")
        local getgc = getgc or get_gc_objects
        if type(getgc) == "function" then
            local gcs = getgc(true) or {}
            local scanned = 0
            for _, v in ipairs(gcs) do
                scanned = scanned + 1
                if scanned % 5000 == 0 then task.wait() end
                if not Refs.Net and type(v) == "table"
                    and type(rawget(v, "act")) == "table"
                    and type(rawget(v, "move")) == "table" then
                    Refs.Net = v
                end
                if not Refs.Inv and type(v) == "table"
                    and type(rawget(v, "slots")) == "table"
                    and type(rawget(v, "count")) == "function" then
                    Refs.Inv = v
                end
                if Refs.Net and Refs.Inv then break end
            end
            print("[KAIRO-DUPE] Scan selesai. Net=" .. tostring(Refs.Net ~= nil)
                .. " Inv=" .. tostring(Refs.Inv ~= nil))
        end
    end
end

if not Refs.Net then
    print("[KAIRO-DUPE] FATAL: Net wrapper nggak ketemu. Jalanin BETARIA dulu, atau inject ulang.")
    return
end

-- ---------------------------------------------------------------------
-- Config
-- ---------------------------------------------------------------------
local KAIRO = {
    ITEM_ID   = 2488,
    COUNT     = 200,
    RACE_MS   = 15,
    CYCLES    = 30,
    COOLDOWN  = 300,
    Running   = false,
    Found     = { drop = nil, buy = nil, trade = nil },
    Stats     = { cycles = 0, ok = 0, fail = 0, lastErr = "-" },
}

-- ---------------------------------------------------------------------
-- Enumerate Net.act untuk drop/buy/trade
-- ---------------------------------------------------------------------
local function klog(m) print("[KAIRO-DUPE] " .. tostring(m)) end

local function enumerate()
    KAIRO.Found.drop, KAIRO.Found.buy, KAIRO.Found.trade = nil, nil, nil
    local patterns = {
        drop  = {"drop", "dropitem", "drop_item", "throw"},
        buy   = {"buy", "buyitem", "purchase", "nupirkti", "acquire"},
        trade = {"trade", "offer", "give", "transfer"},
    }
    for _, subName in ipairs({"act", "move", "tile", "inv", "inventory"}) do
        local sub = rawget(Refs.Net, subName)
        if type(sub) == "table" then
            for name, fn in pairs(sub) do
                if type(name) == "string" and type(fn) == "function" then
                    local lname = name:lower()
                    for cat, wants in pairs(patterns) do
                        if not KAIRO.Found[cat] then
                            for _, w in ipairs(wants) do
                                if lname == w or lname:find(w, 1, true) then
                                    KAIRO.Found[cat] = {
                                        path = ("Net.%s.%s"):format(subName, name),
                                        fn = fn, sub = subName, name = name,
                                    }
                                    klog(("★ %s -> Net.%s.%s"):format(cat, subName, name))
                                    if debug and debug.info then
                                        local ok, params = pcall(debug.info, fn, "a")
                                        if ok then klog("  params: " .. tostring(params)) end
                                    end
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return KAIRO.Found.drop or KAIRO.Found.buy
end

-- ---------------------------------------------------------------------
-- Multi-signature caller
-- ---------------------------------------------------------------------
local function callAct(entry, id, count)
    if not entry or type(entry.fn) ~= "function" then return false end
    local tries = {
        function() return entry.fn(id, count) end,
        function() return entry.fn({ id = id, count = count }) end,
        function() return entry.fn(id, count, false) end,
        function() return entry.fn(entry.sub, id, count) end,
        function() return entry.fn(id, count, 0, 0) end,
    }
    for i, fn in ipairs(tries) do
        local ok, err = pcall(fn)
        if ok then return true, i end
        KAIRO.Stats.lastErr = tostring(err):sub(1, 80)
    end
    return false
end

-- ---------------------------------------------------------------------
-- Dupe loop
-- ---------------------------------------------------------------------
local function dupeLoop()
    if not KAIRO.Found.drop and not KAIRO.Found.buy then
        klog("ABORT: nggak ada drop/buy wrapper.")
        return
    end
    KAIRO.Running = true
    KAIRO.Stats = { cycles = 0, ok = 0, fail = 0, lastErr = "-" }
    klog(("START item=%d count=%d race=%dms cycles=%d"):format(
        KAIRO.ITEM_ID, KAIRO.COUNT, KAIRO.RACE_MS, KAIRO.CYCLES))

    for c = 1, KAIRO.CYCLES do
        if not KAIRO.Running then break end
        KAIRO.Stats.cycles = c

        if KAIRO.Found.buy then
            local o1 = callAct(KAIRO.Found.buy, KAIRO.ITEM_ID, KAIRO.COUNT)
            task.wait(KAIRO.RACE_MS / 1000)
            local o2 = callAct(KAIRO.Found.buy, KAIRO.ITEM_ID, KAIRO.COUNT)
            task.wait(KAIRO.RACE_MS / 1000)
            if o1 or o2 then KAIRO.Stats.ok += 1 else KAIRO.Stats.fail += 1 end
        end

        if KAIRO.Found.drop then
            local od = callAct(KAIRO.Found.drop, KAIRO.ITEM_ID, KAIRO.COUNT)
            if od then KAIRO.Stats.ok += 1 else KAIRO.Stats.fail += 1 end
        end

        task.wait(KAIRO.COOLDOWN / 1000)
    end
    KAIRO.Running = false
    klog(("DONE ok=%d fail=%d"):format(KAIRO.Stats.ok, KAIRO.Stats.fail))
end

-- ---------------------------------------------------------------------
-- UI
-- ---------------------------------------------------------------------
local oldGui = PlayerGui:FindFirstChild("KAIRO_DUPE")
if oldGui then oldGui:Destroy() end

local sg = Instance.new("ScreenGui")
sg.Name = "KAIRO_DUPE"
sg.ResetOnSpawn = false
sg.IgnoreGuiInset = true
sg.DisplayOrder = 998
sg.Parent = PlayerGui

local function round(o, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r)
    c.Parent = o
end

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 260, 0, 320)
panel.Position = UDim2.new(1, -280, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(12, 12, 14)
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true
panel.Parent = sg
round(panel, 8)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 30)
header.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
header.Parent = panel
round(header, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -30, 1, 0)
title.Position = UDim2.new(0, 10, 0, 0)
title.BackgroundTransparency = 1
title.Text = "KAIRO DUPE | Standalone"
title.TextColor3 = Color3.fromRGB(255, 60, 60)
title.Font = Enum.Font.Code
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 22, 0, 22)
close.Position = UDim2.new(1, -26, 0.5, -11)
close.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 60, 60)
close.Font = Enum.Font.Code
close.TextSize = 11
close.Parent = header
round(close, 4)
close.MouseButton1Click:Connect(function() panel.Visible = false end)

-- Status label
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 90)
status.Position = UDim2.new(0, 10, 0, 38)
status.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
status.Text = "Net: " .. tostring(Refs.Net ~= nil) .. " | Inv: " .. tostring(Refs.Inv ~= nil) .. "\n\nKlik SCAN buat enumerasi."
status.TextColor3 = Color3.fromRGB(200, 200, 200)
status.Font = Enum.Font.Code
status.TextSize = 10
status.TextWrapped = true
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Parent = panel
round(status, 4)

local function mkInput(y, label, default)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(0, 90, 0, 22)
    l.Position = UDim2.new(0, 10, 0, y)
    l.BackgroundTransparency = 1
    l.Text = label
    l.TextColor3 = Color3.fromRGB(220, 220, 220)
    l.Font = Enum.Font.Code
    l.TextSize = 10
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.Parent = panel
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 140, 0, 22)
    box.Position = UDim2.new(0, 110, 0, y)
    box.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    box.Text = tostring(default)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.Font = Enum.Font.Code
    box.TextSize = 11
    box.Parent = panel
    round(box, 4)
    return box
end

local inItem = mkInput(135, "Item ID", KAIRO.ITEM_ID)
local inCount = mkInput(161, "Count", KAIRO.COUNT)
local inRace = mkInput(187, "Race ms", KAIRO.RACE_MS)
local inCycles = mkInput(213, "Cycles", KAIRO.CYCLES)

local function readInputs()
    KAIRO.ITEM_ID = tonumber(inItem.Text) or KAIRO.ITEM_ID
    KAIRO.COUNT = tonumber(inCount.Text) or KAIRO.COUNT
    KAIRO.RACE_MS = tonumber(inRace.Text) or KAIRO.RACE_MS
    KAIRO.CYCLES = tonumber(inCycles.Text) or KAIRO.CYCLES
end

local btnScan = Instance.new("TextButton")
btnScan.Size = UDim2.new(0, 110, 0, 28)
btnScan.Position = UDim2.new(0, 10, 0, 242)
btnScan.BackgroundColor3 = Color3.fromRGB(40, 40, 90)
btnScan.Text = "SCAN"
btnScan.TextColor3 = Color3.fromRGB(200, 200, 255)
btnScan.Font = Enum.Font.Code
btnScan.TextSize = 11
btnScan.Parent = panel
round(btnScan, 4)

local btnStart = Instance.new("TextButton")
btnStart.Size = UDim2.new(0, 110, 0, 28)
btnStart.Position = UDim2.new(0, 130, 0, 242)
btnStart.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
btnStart.Text = "START"
btnStart.TextColor3 = Color3.fromRGB(255, 120, 120)
btnStart.Font = Enum.Font.Code
btnStart.TextSize = 11
btnStart.Parent = panel
round(btnStart, 4)

local btnStop = Instance.new("TextButton")
btnStop.Size = UDim2.new(1, -20, 0, 26)
btnStop.Position = UDim2.new(0, 10, 0, 278)
btnStop.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
btnStop.Text = "STOP"
btnStop.TextColor3 = Color3.fromRGB(255, 120, 120)
btnStop.Font = Enum.Font.Code
btnStop.TextSize = 11
btnStop.Parent = panel
round(btnStop, 4)

local function refreshStatus()
    local f = KAIRO.Found
    status.Text = string.format(
        "Net: %s | Inv: %s\nDrop: %s\nBuy: %s\nTrade: %s\n\nCycles: %d | ok=%d fail=%d\nLast err: %s",
        tostring(Refs.Net ~= nil), tostring(Refs.Inv ~= nil),
        f.drop and f.drop.path or "-",
        f.buy and f.buy.path or "-",
        f.trade and f.trade.path or "-",
        KAIRO.Stats.cycles, KAIRO.Stats.ok, KAIRO.Stats.fail,
        KAIRO.Stats.lastErr:sub(1, 60)
    )
end

btnScan.MouseButton1Click:Connect(function()
    readInputs()
    enumerate()
    refreshStatus()
end)

btnStart.MouseButton1Click:Connect(function()
    readInputs()
    if KAIRO.Running then return end
    task.spawn(function()
        dupeLoop()
        refreshStatus()
    end)
end)

btnStop.MouseButton1Click:Connect(function()
    KAIRO.Running = false
    refreshStatus()
end)

task.spawn(function()
    while sg.Parent do
        refreshStatus()
        task.wait(1)
    end
end)

-- ---------------------------------------------------------------------
-- Auto-enumerate setelah load
-- ---------------------------------------------------------------------
task.spawn(function()
    task.wait(1)
    enumerate()
    refreshStatus()
    klog("Standalone ready. Buka panel KAIRO DUPE di pojok kanan atas.")
end)

G.KAIRO_DUPE = KAIRO
