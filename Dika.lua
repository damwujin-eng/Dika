local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local function gcAll()
    local ok, all = pcall(getgc, true)
    if ok and typeof(all) == "table" then
        return all
    end
end

local world
local function findWorld()
    if world then
        return
    end
    local all = gcAll()
    if not all then
        return
    end
    for _, t in pairs(all) do
        if typeof(t) == "table"
            and type(rawget(t, "w")) == "number"
            and type(rawget(t, "h")) == "number"
            and typeof(rawget(t, "fg")) == "table"
            and typeof(rawget(t, "goTo")) == "function" then
            world = t
            return
        end
    end
end

local posMode
local posX, posY
local posDiag = "not scanned"

local function getUps(fn)
    if typeof(fn) ~= "function" then
        return nil, "not a function"
    end
    local ok1, u1 = pcall(function()
        return debug.getupvalues(fn)
    end)
    if ok1 and typeof(u1) == "table" and next(u1) then
        return u1, "debug"
    end
    if typeof(getupvalues) == "function" then
        local ok2, u2 = pcall(getupvalues, fn)
        if ok2 and typeof(u2) == "table" and next(u2) then
            return u2, "getupvalues"
        end
    end
    return nil, "no upvalues"
end

local function findPos()
    if not world then
        posDiag = "no world"
        return
    end
    local ups, how = getUps(rawget(world, "goTo"))
    if not ups then
        posDiag = "ups:" .. tostring(how)
        return
    end
    if type(ups[1]) == "number" and type(ups[2]) == "number" then
        posX, posY = ups[1], ups[2]
        posMode = "num"
        posDiag = how .. " nums"
        return
    end
    local got = {}
    for _, u in pairs(ups) do
        if typeof(u) == "table" and type(rawget(u, 1)) == "number" then
            got[#got + 1] = u
        end
    end
    if #got >= 2 then
        posX, posY = got[1], got[2]
        posMode = "tbl"
        posDiag = how .. " tables"
    else
        posDiag = "found " .. tostring(#got) .. " (" .. tostring(how) .. ")"
    end
end

local function readPos()
    if posMode == "num" and world then
        local ups = getUps(rawget(world, "goTo"))
        if ups and type(ups[1]) == "number" and type(ups[2]) == "number" then
            posX, posY = ups[1], ups[2]
            return posX, posY
        end
        return nil, nil
    elseif posMode == "tbl" then
        return posX[1], posY[1]
    end
end

local itemDb
local function findItemDb()
    if itemDb then
        return
    end
    local all = gcAll()
    if not all then
        return
    end
    for _, t in pairs(all) do
        if typeof(t) == "table" then
            local d = rawget(t, 2)
            if typeof(d) == "table" and rawget(d, "name") == "Dirt" then
                itemDb = t
                return
            end
        end
    end
end

local function tileNow()
    local x, y = readPos()
    if not (x and y) then
        return nil, nil
    end
    return math.floor(x), math.floor(y - 0.475)
end

local function tileId(x, y)
    if not world or typeof(world.fg) ~= "table" then
        return 0
    end
    local row = world.fg[y]
    local id = (row and row[x]) or 0
    if typeof(id) ~= "number" then
        return 0
    end
    return id
end

local function tileLabel(x, y)
    local id = tileId(x, y)
    local def = itemDb and itemDb[id]
    return string.format("%s (%d)", (def and def.name) or "Air", id)
end

local function writePos(nx, ny)
    if typeof(debug.setupvalues) ~= "function" or not world then
        return false, "no setupvalues"
    end
    local ups = getUps(rawget(world, "goTo"))
    if not ups then
        return false, "no ups"
    end
    local ox, oy = nil, nil
    if type(ups[1]) == "number" and type(ups[2]) == "number" then
        ox, oy = ups[1], ups[2]
    end
    local patch = { [1] = nx, [2] = ny }
    local n = 0
    for i = 1, #ups do
        local v = ups[i]
        if type(v) == "number" and ox then
            if math.abs(v - ox) < 1e-6 then
                patch[i] = nx
                n = n + 1
            elseif math.abs(v - oy) < 1e-6 then
                patch[i] = ny
                n = n + 1
            elseif math.abs(v - (oy - 0.5)) < 1e-6 then
                patch[i] = ny - 0.5
                n = n + 1
            end
        end
    end
    local ok, err = pcall(debug.setupvalues, rawget(world, "goTo"), patch)
    if not ok then
        return false, tostring(err)
    end
    return true, "slots " .. tostring(n)
end

local function attempt(tx, ty)
    local okGo, errGo = pcall(world.goTo, tx, ty)
    local okSet, msgSet = writePos(tx + 0.5, ty + 1)
    return okGo, errGo, okSet, msgSet
end

local gui = Instance.new("ScreenGui")
gui.Name = "HowlNoclip"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 999
do
    local ok, hui = pcall(function()
        return gethui and gethui()
    end)
    gui.Parent = (ok and hui) or game:GetService("CoreGui")
end

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(272, 306)
frame.Position = UDim2.new(0.5, -136, 0, 64)
frame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -40, 0, 34)
title.Position = UDim2.fromOffset(10, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(235, 238, 245)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Noclip"
title.Parent = frame

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(30, 30)
close.Position = UDim2.new(1, -34, 0, 2)
close.BackgroundColor3 = Color3.fromRGB(48, 50, 60)
close.TextColor3 = Color3.fromRGB(235, 238, 245)
close.Font = Enum.Font.GothamBold
close.TextSize = 14
close.Text = "X"
close.Parent = frame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 6)
closeCorner.Parent = close

local here = Instance.new("TextLabel")
here.Size = UDim2.new(1, -20, 0, 20)
here.Position = UDim2.fromOffset(10, 36)
here.BackgroundTransparency = 1
here.Font = Enum.Font.Code
here.TextSize = 13
here.TextColor3 = Color3.fromRGB(150, 200, 255)
here.TextXAlignment = Enum.TextXAlignment.Left
here.Text = "Reading position..."
here.Parent = frame

local function makeBox(x)
    local box = Instance.new("TextBox")
    box.Size = UDim2.fromOffset(78, 32)
    box.Position = UDim2.fromOffset(x, 60)
    box.BackgroundColor3 = Color3.fromRGB(36, 39, 47)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Code
    box.TextSize = 14
    box.TextColor3 = Color3.fromRGB(235, 238, 245)
    box.PlaceholderText = "0"
    box.Text = ""
    box.ClearTextOnFocus = false
    box.Parent = frame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = box
    return box
end

local xBox = makeBox(10)
local yBox = makeBox(96)

local function makeButton(text, x, y, w, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(w, 32)
    b.Position = UDim2.fromOffset(x, y)
    b.BackgroundColor3 = Color3.fromRGB(48, 52, 64)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamMedium
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(235, 238, 245)
    b.Text = text
    b.Parent = frame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = b
    b.MouseButton1Click:Connect(cb)
    return b
end

local logLabel = Instance.new("TextLabel")
logLabel.Size = UDim2.new(1, -20, 0, 92)
logLabel.Position = UDim2.fromOffset(10, 206)
logLabel.BackgroundColor3 = Color3.fromRGB(16, 18, 22)
logLabel.BorderSizePixel = 0
logLabel.Font = Enum.Font.Code
logLabel.TextSize = 11
logLabel.TextWrapped = true
logLabel.TextColor3 = Color3.fromRGB(210, 215, 225)
logLabel.TextXAlignment = Enum.TextXAlignment.Left
logLabel.TextYAlignment = Enum.TextYAlignment.Top
logLabel.Text = ""
logLabel.Parent = frame
local logCorner = Instance.new("UICorner")
logCorner.CornerRadius = UDim.new(0, 6)
logCorner.Parent = logLabel

local function setLog(text)
    logLabel.Text = text
end

local function refreshHere()
    local x, y = tileNow()
    if x then
        here.Text = string.format("%d, %d  |  %s", x, y, tileLabel(x, y))
    else
        here.Text = "Position unknown (" .. tostring(posDiag) .. ")"
    end
end

local function ensure()
    if not world then
        findWorld()
    end
    if world and not posMode then
        findPos()
    end
end

local function fillCurrent()
    ensure()
    local x, y = tileNow()
    if x then
        xBox.Text = tostring(x)
        yBox.Text = tostring(y)
    end
end

local function report(tx, ty, okGo, errGo, okSet, msgSet)
    local x0, y0 = readPos()
    setLog(string.format(
        "-> %d,%d (now %.2f,%.2f)\n%s\n%s\nat %s",
        tx, ty, x0 or -1, y0 or -1,
        "goTo: " .. (okGo and "ok" or tostring(errGo)),
        "set: " .. (okSet and tostring(msgSet) or tostring(msgSet)),
        tileLabel(tx, ty)
    ))
end

local function teleportTo(tx, ty)
    ensure()
    if not world then
        setLog("World not found")
        return
    end
    if not posMode then
        setLog("Position not found: " .. tostring(posDiag))
        return
    end
    local okGo, errGo, okSet, msgSet = attempt(tx, ty)
    report(tx, ty, okGo, errGo, okSet, msgSet)
end

local ghostOn = false
local ghostBtn

local function applyGhost()
    if not world then
        return
    end
    pcall(function()
        world.ghost = ghostOn
    end)
end

local function toggleGhost()
    ensure()
    ghostOn = not ghostOn
    applyGhost()
    ghostBtn.Text = ghostOn and "Ghost: ON" or "Ghost: OFF"
    ghostBtn.BackgroundColor3 = ghostOn and Color3.fromRGB(150, 60, 60) or Color3.fromRGB(48, 52, 64)
    setLog(ghostOn and "Ghost on: walk through walls (WASD)" or "Ghost off")
end

local function go()
    local tx = tonumber(xBox.Text)
    local ty = tonumber(yBox.Text)
    if not tx or not ty then
        setLog("Bad X/Y")
        return
    end
    teleportTo(math.floor(tx), math.floor(ty))
end

local VIM = game:GetService("VirtualInputManager")

local function tapKey(key, hold)
    local ok = pcall(function()
        VIM:SendKeyEvent(true, key, false, game)
    end)
    task.delay(hold, function()
        pcall(function()
            VIM:SendKeyEvent(false, key, false, game)
        end)
    end)
    return ok
end

local function tapMove(label, key)
    ensure()
    local x0, y0 = readPos()
    local ok = tapKey(key, 0.05)
    task.delay(0.2, function()
        local x1, y1 = readPos()
        setLog(string.format(
            "%s  key %s (%s)\nfrom %.2f,%.2f\nnow  %.2f,%.2f",
            label, key.Name, ok and "sent" or "fail",
            x0 or -1, y0 or -1, x1 or -1, y1 or -1
        ))
    end)
end

makeButton("Here", 186, 60, 76, fillCurrent)
ghostBtn = makeButton("Ghost: OFF", 10, 100, 252, toggleGhost)
local goBtn = makeButton("Teleport X/Y", 10, 136, 252, go)
goBtn.BackgroundColor3 = Color3.fromRGB(58, 122, 96)
makeButton("Down .5", 10, 172, 60, function()
    tapMove("Down", Enum.KeyCode.Down)
end)
makeButton("Up .5", 74, 172, 60, function()
    tapMove("Up", Enum.KeyCode.Up)
end)
makeButton("Left .5", 138, 172, 60, function()
    tapMove("Left", Enum.KeyCode.Left)
end)
makeButton("Right .5", 202, 172, 60, function()
    tapMove("Right", Enum.KeyCode.Right)
end)

task.spawn(function()
    ensure()
    fillCurrent()
    refreshHere()
    while gui.Parent do
        task.wait(0.5)
        refreshHere()
        if ghostOn then
            applyGhost()
        end
    end
end)

close.MouseButton1Click:Connect(function()
    ghostOn = false
    applyGhost()
    gui:Destroy()
end)

local dragging, dragStart, startPos
frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement) then
        local d = input.Position - dragStart
        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
----------------------------------------------------------------
-- SUSUNAN MENU BARU: grup, urutan & nama tab
--   Farming: Auto Farm, Harvest, Splice | World: Clear World, Dirt Farm, Pabrik
--   Shop: Drop, Titik Drop, Vending, Tas | Info: Growscan, Statistik
--   Utilitas: Auto Chat, World Finder, Lainnya | Keamanan: Auto Mods, Auto Reconnect
--   Setelan: Umum, Performa, Koneksi & Config, Discord
---------------------------------------------------------------------
local LAYOUT = {
    {
        name = "grup World, Shop, Info",
        old = [==[{ key = "farm", title = "Farming", icon = "sprout", opened = true },]==],
        new = [==[{ key = "farm", title = "Farming", icon = "sprout", opened = true },
    { key = "world", title = "World", icon = "map" },
    { key = "shop", title = "Shop", icon = "shopping-bag" },
    { key = "info", title = "Info", icon = "info" },]==],
    },
    {
        name = "grup Utilitas",
        old = [==[{ key = "fitur", title = "Fitur", icon = "sparkles" },]==],
        new = [==[{ key = "fitur", title = "Utilitas", icon = "sparkles" },]==],
    },
    {
        name = "urutan dan nama tab",
        old = [==[local function makeTab(title, icon, group)]==],
        new = [==[Session.PreTabs = {}
do (function()
    -- { judul lama (dipakai kode), judul baru, ikon, grup }. Urutan di sini = urutan di sidebar.
    local PLAN = {
        { "Farm", "Auto Farm", "pickaxe", "farm" },
        { "Farmer", "Harvest", "leaf", "farm" },
        { "Splice", "Splice", "git-merge", "farm" },
        { "Clear World", "Clear World", "eraser", "world" },
        { "Lahan", "Dirt Farm", "layout-grid", "world" },
        { "Pabrik", "Pabrik", "factory", "world" },
        { "Auto Drop", "Drop", "package-open", "shop" },
        { "Titik Drop", "Titik Drop", "map-pin", "shop" },
        { "Vending", "Vending", "store", "shop" },
        { "Tas", "Tas", "backpack", "shop" },
        { "Growscan", "Growscan", "scan-search", "info" },
        { "Statistik", "Statistik", "bar-chart-3", "info" },
        { "Auto Chat", "Auto Chat", "message-circle", "fitur" },
        { "World Finder", "World Finder", "globe", "fitur" },
        { "Bonus", "Lainnya", "gift", "fitur" },
        { "Penjaga", "Auto Mods", "eye", "aman" },
        { "Auto Reconnect", "Auto Reconnect", "refresh-cw", "aman" },
        { "Pengaturan", "Umum", "sliders-horizontal", "setel" },
        { "Performa", "Performa", "gauge", "setel" },
        { "Koneksi", "Koneksi & Config", "plug", "setel" },
        { "Discord", "Discord", "bell", "setel" },
    }
    for _, e in ipairs(PLAN) do
        local section = Groups[e[4]]
        if section then
            local ok, tab = pcall(function() return section:Tab({ Title = e[2], Icon = e[3] }) end)
            if ok and tab then Session.PreTabs[e[1]] = tab end
        end
    end
end)() end

local function makeTab(title, icon, group)
    local cached = Session.PreTabs[title]
    if cached then return cached end
    local created = Session.rawTab(title, icon, group)
    Session.PreTabs[title] = created
    return created
end

Session.rawTab = function(title, icon, group)]==],
    },
    {
        name = "Auto Reconnect jadi tab Keamanan",
        old = [==[local rBox = box(ConnTab, "Auto Reconnect", false)]==],
        new = [==[local rBox = box(makeTab("Auto Reconnect", "refresh-cw", "aman"), "Auto Reconnect", true)]==],
    },
    {
        name = "kotak Performa",
        old = [==[Box.SetOpt = box(SetTab, "Opsi", true)]==],
        new = [==[Box.SetOpt = box(SetTab, "Opsi", true)
Box.SetPerf = box(makeTab("Performa", "gauge", "setel"), "Performa", true)]==],
    },
    {
        name = "Mode Lite ke Performa",
        old = "OptTab:Toggle({\n        Title = \"Mode Lite\",",
        new = "Box.SetPerf:Toggle({\n        Title = \"Mode Lite\",",
    },
    {
        name = "Mute suara ke Performa",
        old = "OptTab:Toggle({\n        Title = \"Mute suara pukulan\",",
        new = "Box.SetPerf:Toggle({\n        Title = \"Mute suara pukulan\",",
    },
    {
        name = "Animasi aksi ke Performa",
        old = "OptTab:Toggle({\n        Title = \"Animasi aksi\",",
        new = "Box.SetPerf:Toggle({\n        Title = \"Animasi aksi\",",
    },
    {
        name = "terjemahan English",
        old = [==[["Fitur"] = "Features", ["Keamanan"] = "Security", ["Setelan"] = "Setup",]==],
        new = [==[["Fitur"] = "Features", ["Keamanan"] = "Security", ["Setelan"] = "Setup",
    ["Utilitas"] = "Utilities", ["Umum"] = "General", ["Performa"] = "Performance",
    ["Koneksi & Config"] = "Connection & Config",
    ["Status Harvest"] = "Harvest Status", ["Jalankan Harvest"] = "Run Harvest",
    ["Status Dirt Farm"] = "Dirt Farm Status", ["Bangun Dirt Farm"] = "Build Dirt Farm",
    ["Status Auto Mods"] = "Auto Mods Status", ["Aktifkan Auto Mods"] = "Enable Auto Mods",]==],
    },
}

---------------------------------------------------------------------
-- RAPI-IN UI: tab Farm. Collect & kecepatan (global) pindah ke Setelan > Umum,
-- Auto Break Block pindah ke tab Clear World.
---------------------------------------------------------------------
local FARMUI = {
    {
        name = "judul kotak Auto Farm",
        old = [==[Box.FarmCtl = box(FarmTab, "Kontrol", true)]==],
        new = [==[Box.FarmCtl = box(FarmTab, "Auto Farm", true)]==],
    },
    {
        name = "kotak Mode, Collect, Kecepatan",
        old = [==[Box.FarmSpeed = box(FarmTab, "Mode & Kecepatan", false)]==],
        new = [==[Box.FarmSpeed = box(FarmTab, "Mode", false)
Box.GlobCollect = box(makeTab("Pengaturan", "sliders-horizontal", "setel"), "Collect", false)
Box.GlobSpeed = box(makeTab("Pengaturan", "sliders-horizontal", "setel"), "Kecepatan", false)]==],
    },
    {
        name = "Auto Collect pindah",
        old = "Box.FarmCtl:Toggle({\n        Title = \"Auto Collect\",",
        new = "Box.GlobCollect:Toggle({\n        Title = \"Auto Collect\",",
    },
    {
        name = "Mode collect pindah",
        old = "Box.FarmCtl:Dropdown({\n        Title = \"Mode collect\",",
        new = "Box.GlobCollect:Dropdown({\n        Title = \"Mode collect\",",
    },
    {
        name = "Radius collect pindah",
        old = "addNumber(Box.FarmCtl, {\n    Title = \"Radius collect (mode Remote)\",",
        new = "addNumber(Box.GlobCollect, {\n    Title = \"Radius collect (mode Remote)\",",
    },
    {
        name = "Speed Place pindah",
        old = "addNumber(SpeedTab, {\n    Title = \"Speed Place (ms)\",",
        new = "addNumber(Box.GlobSpeed, {\n    Title = \"Speed Place (ms)\",",
    },
    {
        name = "Speed Break pindah",
        old = "addNumber(SpeedTab, {\n    Title = \"Speed Break (ms)\",",
        new = "addNumber(Box.GlobSpeed, {\n    Title = \"Speed Break (ms)\",",
    },
    {
        name = "Auto Break Block pindah ke Clear World",
        old = [==[local controls = box(FarmTab, "Auto Break Block", true)]==],
        new = [==[local controls = box(makeTab("Clear World", "eraser", "world"), "Auto Break Block", false)]==],
    },
}

---------------------------------------------------------------------
-- GANTI NAMA yang kelihatan di menu: Farmer -> Harvest, Lahan -> Dirt Farm, Penjaga -> Auto Mods
---------------------------------------------------------------------
local RENAME = {
    {
        name = "judul notifikasi",
        old = [==[Title = I18N.T(title), Content = I18N.T(content)]==],
        new = [==[Title = I18N.T(({ Penjaga = "Auto Mods", Lahan = "Dirt Farm", ["Bangun Lahan"] = "Dirt Farm", Farmer = "Harvest" })[title] or title), Content = I18N.T(content)]==],
    },
    { name = "Status Farmer", old = [==[Title = "Status Farmer"]==], new = [==[Title = "Status Harvest"]==] },
    { name = "Jalankan Farmer", old = [==[Title = "Jalankan Farmer",]==], new = [==[Title = "Jalankan Harvest",]==] },
    { name = "Status Lahan", old = [==[Title = "Status Lahan"]==], new = [==[Title = "Status Dirt Farm"]==] },
    { name = "kotak Bangun Lahan", old = [==[local lCtl = box(LTab, "Bangun Lahan", true)]==], new = [==[local lCtl = box(LTab, "Bangun Dirt Farm", true)]==] },
    { name = "toggle Bangun Lahan", old = [==[Title = "Bangun Lahan",]==], new = [==[Title = "Bangun Dirt Farm",]==] },
    { name = "Status Penjaga", old = [==[Title = "Status Penjaga"]==], new = [==[Title = "Status Auto Mods"]==] },
    { name = "Aktifkan Penjaga", old = [==[Title = "Aktifkan Penjaga",]==], new = [==[Title = "Aktifkan Auto Mods",]==] },
}


---------------------------------------------------------------------
-- NAMA: n4th -> utimeme (judul menu, tombol buka, watermark nama di atas karakter, notifikasi)
-- Nama folder config dan nama internal tidak diubah, supaya pengaturan lama tidak hilang.
---------------------------------------------------------------------
local BRAND = {
    { name = "judul jendela", old = "WindUI:CreateWindow({\n    Title = \"n4th\",", new = "WindUI:CreateWindow({\n    Title = \"Dika\"," },
    { name = "tombol buka menu", old = "Window:EditOpenButton({\n        Title = \"n4th\",", new = "Window:EditOpenButton({\n        Title = \"Dika\"," },
    { name = "popup bahasa", old = "WindUI:Popup({\n            Title = \"n4th\",", new = "WindUI:Popup({\n            Title = \"Dika\"," },
    { name = "nama di atas karakter", old = [==[NameText = "n4th",]==], new = [==[NameText = "Dika",]==] },
    { name = "nama pengirim Discord", old = [==[username = "n4th",]==], new = [==[username = "Dika",]==] },
    { name = "tes notifikasi", old = [==[Hook.send("test", "Tes notifikasi dari n4th")]==], new = [==[Hook.send("test", "Tes notifikasi dari Dika")]==] },
    { name = "tes notifikasi EN", old = [==[["Tes notifikasi dari n4th"] = "Test notification from n4th",]==], new = [==[["Tes notifikasi dari Dika"] = "Test notification from Dika",]==] },
    { name = "tes World Finder", old = [==["World Finder siap mengirim hasil hunting dari n4th"]==], new = [==["World Finder siap mengirim hasil hunting dari Dika"]==] },
    { name = "notifikasi koneksi", old = [==[reconnect("n4th v5.2")]==], new = [==[reconnect("Dika")]==] },
}


---------------------------------------------------------------------
-- HUBUNGKAN OTOMATIS: kalau sudah di dalam world tapi data world / tas belum ketemu
-- (misal script dijalankan sebelum world siap), coba hubungkan ulang sendiri.
---------------------------------------------------------------------
local AUTOLINK = {
    {
        name = "hubungkan otomatis",
        old = [==[Session.InitStep = "siap"]==],
        new = [==[task.spawn(function()
    task.wait(8)
    local tries = 0
    while alive() do
        if not (Refs.World and Refs.Inv) and getPlayerTile() then
            tries += 1
            if tries <= 5 or tries % 8 == 0 then
                UI.later("autoLink", function() reconnect("Hubungkan otomatis") end)
            end
        else
            tries = 0
            if not UI.DropOk then
                UI.later("autoDropdown", function() doInvRefresh(true) end)
            end
        end
        task.wait(tries <= 5 and 8 or 8)
    end
end)

Session.InitStep = "siap"]==],
    },
}


---------------------------------------------------------------------
-- PERBAIKAN DROPDOWN: isi daftar langsung dulu; kalau gagal baru lewat jalur izin penuh (lama)
---------------------------------------------------------------------
local DROPFIX = {
    {
        name = "refresh dropdown langsung",
        old = [==[function UI.ddRefresh(dd, labels)]==],
        new = [==[function UI.ddRefresh(dd, labels)
    if dd and pcall(function() dd:Refresh(labels) end) then
        UI.DropOk = os.clock()
        UI.DropErr = nil
        return
    end
    return UI.ddRefreshElevated(dd, labels)
end

function UI.ddRefreshElevated(dd, labels)]==],
    },
}

-- Semua teks harus muncul tepat 1x; kalau tidak, seluruh daftar dilewati.
local function applyPatches(source, list)
    local out = source
    for _, p in ipairs(list) do
        local s, e = out:find(p.old, 1, true)
        if not s then return nil, p.name .. " (teks tidak ketemu)" end
        if out:find(p.old, e + 1, true) then return nil, p.name .. " (muncul lebih dari satu kali)" end
        out = out:sub(1, s - 1) .. p.new .. out:sub(e + 1)
    end
    return out
end

---------------------------------------------------------------------
-- DOWNLOAD
---------------------------------------------------------------------
local function usable(text)
    return type(text) == "string" and not text:match("^%s*$") and not text:match("^%s*<")
end

local function download(url)
    local ok, body = pcall(function() return game:HttpGet(url) end)
    if ok and usable(body) then return body end
    for _, api in ipairs({ request or false, http_request or false, (syn and syn.request) or false, (http and http.request) or false }) do
        if type(api) == "function" then
            local sent, res = pcall(api, { Url = url, Method = "GET" })
            if sent and type(res) == "table" then
                local status = tonumber(res.StatusCode or res.Status)
                local text = res.Body or res.body
                if (not status or (status >= 200 and status < 300)) and usable(text) then return text end
            end
        end
    end
    error("[AFK] Unduh gagal: " .. url, 0)
end

local function latestSource()
    local okRef, ref = pcall(function()
        local url = "https://api.github.com/repos/" .. repository .. "/git/ref/heads/main?update=" .. httpService:GenerateGUID(false)
        return httpService:JSONDecode(download(url))
    end)
    local commit = okRef and type(ref) == "table" and type(ref.object) == "table" and ref.object.sha
    if type(commit) == "string" and #commit == 40 and commit:match("^%x+$") then
        local ok, body = pcall(download, "https://raw.githubusercontent.com/" .. repository .. "/" .. commit .. "/n4th-main.lua")
        if ok then return body, commit:sub(1, 8) end
    end
    return download("https://raw.githubusercontent.com/" .. repository .. "/main/n4th-main.lua"), "main"
end

---------------------------------------------------------------------
-- JALANKAN
---------------------------------------------------------------------
local function pickCompiled(source)
    source = (source:gsub("\r\n", "\n"))
    local fixed, fixProblem = applyPatches(source, FIX)
    if not fixed then print("[AFK] Perbaikan kompilasi tidak dipasang: " .. tostring(fixProblem)) end
    local current, added = fixed or source, {}
    for _, feature in ipairs({ { "AFK", AFK }, { "FPS Boost", FPS }, { "Susunan menu", LAYOUT }, { "UI Farm", FARMUI }, { "Nama baru", RENAME }, { "Nama utimeme", BRAND }, { "Hubungkan otomatis", AUTOLINK }, { "Perbaikan dropdown", DROPFIX } }) do
        local patched, problem = applyPatches(current, feature[2])
        if patched then
            current = patched
            added[#added + 1] = feature[1]
        else
            print("[AFK] Fitur " .. feature[1] .. " dilewati: " .. tostring(problem))
        end
    end
    local candidates = {}
    if #added > 0 then
        candidates[#candidates + 1] = {
            text = current,
            label = (fixed and "perbaikan + " or "") .. table.concat(added, " + "),
        }
    end
    if fixed then candidates[#candidates + 1] = { text = fixed, label = "perbaikan saja" } end
    candidates[#candidates + 1] = { text = source, label = "script asli" }
    local lastCompileError
    for _, c in ipairs(candidates) do
        local fn, err = loadstring(c.text, "n4th-main")
        if fn then return fn, c.label end
        lastCompileError = tostring(err)
        print("[AFK] Gagal dikompilasi (" .. c.label .. "): " .. lastCompileError)
    end
    return nil, lastCompileError
end

local lastError = "respons kosong"
for attempt = 1, 3 do
    local ok, source, commit = pcall(latestSource)
    if ok then
        local fn, label = pickCompiled(source)
        if not fn then error("[AFK] Semua versi gagal dikompilasi: " .. tostring(label), 0) end
        print("[AFK] Menjalankan: " .. label .. " (versi " .. tostring(commit) .. ")")
        local ran, result = xpcall(fn, function(err)
            if debug and type(debug.traceback) == "function" then return debug.traceback(tostring(err), 2) end
            return tostring(err)
        end)
        if not ran then
            local globals = (getgenv and getgenv()) or _G
            local session = globals.__n4thOpus
            error("[AFK] Gagal saat " .. tostring(session and session.InitStep or "inisialisasi") .. ":\n" .. tostring(result), 0)
        end
        return result
    end
    lastError = tostring(source)
    if attempt < 3 then task.wait(1) end
end
error("[AFK] Gagal mengambil script setelah 3 percobaan: " .. lastError, 0)
