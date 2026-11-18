-- Growblox (Roblox, PlaceId 112863874972771) - Drop + Spin Roulette Wheel
-- Standalone Luau untuk Delta. BUKAN script Growtopia: tidak ada SendPacket,
-- tidak ada dialog_return, tidak ada "nupirkti" / "pirkti_id" di Growblox.
--
-- Yang diverifikasi dari dump 2026-11-10 + growblox.lua live:
--   * Item 2488 = "Transmatter Field". Roulette Wheel = 758 (spin = true).
--   * Drop legit: Net.drop.send({id=..., n=..., x=..., y=...}),
--     gate World.dropOk(x), jeda antar drop >= 0.3 dtk, titik drop di
--     depan karakter (s.x + facing*0.75, s.y - 0.45).
--   * Spin legit: Net.spin.send({x=tx, y=ty}) -- HANYA koordinat tile.
--     Tidak ada id, count, atau pilihan hadiah. Hadiah ditentukan server
--     dan datang lewat WheelSpun {x, y, n, name, userId}.
--   * Client legit hanya spin kalau punch tile spin/dice, dan ada
--     debounce 0.6 dtk per tile yang sama. Jadi script ini ikut 0.6 dtk.
--   * Drop TIDAK memberi makan wheel dan TIDAK mengubah hasil spin.
--     Drop 2488 x200 lalu spin itu dua aksi terpisah, bukan satu combo.
--
-- Cara pakai: berdiri DEKAT Roulette Wheel (758) di world, pastikan
-- inventory berisi Transmatter Field >= 200, lalu execute.

local ITEM_ID = 242 -- Transmatter Field (terverifikasi dari item table)
local DROP_COUNT = 200
local DROP_DELAY = 0.35 -- >= 0.3 dtk (aturan drop game)
local SPIN_DELAY = 0.7 -- >= 0.6 dtk (debounce spin client)
local MAX_CYCLES = 0 -- 0 = jalan terus sampai inventory < 200 / stop
local WHEEL_ID = 758 -- Roulette Wheel
local MAX_SPIN_DIST = 6 -- tile; lebih jauh dari ini spin kemungkinan diabaikan server

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local function log(msg)
    print("[RouletteDrop] " .. tostring(msg))
end

-- ---------- resolver (shape-based, sama seperti growblox.lua live) ----------
local Shared = nil
local ItemDB = {}
local Net = nil
local Refs = { World = nil, Inv = nil, State = nil }
local getupvalues = (debug and debug.getupvalues) or getupvalues
local getgcFn = getgc

local function isInvTable(v)
    if type(v) ~= "table" then return false end
    local ok, r = pcall(function()
        return type(rawget(v, "slots")) == "table"
            and type(rawget(v, "capacity")) == "number"
            and type(v.count) == "function"
            and type(v.add) == "function"
            and type(v.remove) == "function"
    end)
    return ok and r or false
end

local function isWorldTable(v)
    if type(v) ~= "table" then return false end
    local ok, r = pcall(function()
        return type(rawget(v, "fg")) == "table"
            and type(rawget(v, "bg")) == "table"
            and type(rawget(v, "w")) == "number"
            and type(rawget(v, "h")) == "number"
            and rawget(v, "spawn") ~= nil
    end)
    return ok and r or false
end

local function isStateHolder(v)
    local fn = rawget(v, "state")
    if type(fn) ~= "function" then return false end
    local ok, s = pcall(fn)
    return ok and type(s) == "table" and type(s.x) == "number"
        and type(s.y) == "number" and s.facing ~= nil and s.vx ~= nil
end

local function recoverSharedGlobal()
    if Shared then return end
    local ok, tbl = pcall(function()
        local key = ReplicatedStorage:GetAttribute("Qz")
        if type(key) ~= "string" and type(key) ~= "number" then return nil end
        local g = shared
        if type(g) ~= "table" then return nil end
        return rawget(g, key)
    end)
    if not ok or type(tbl) ~= "table" then return end
    local okS = pcall(function()
        return typeof(rawget(tbl, "j1PKXTgzz")) == "Instance"
            and type(rawget(tbl, "Ui")) == "table"
    end)
    if okS then Shared = tbl end
end

local function findRefs()
    recoverSharedGlobal()
    local gcList = nil
    if getgcFn then
        local okGc, list = pcall(getgcFn, true)
        if okGc and type(list) == "table" then gcList = list end
    end
    local gotItemDB = type(rawget(ItemDB, 112)) == "table"
        and rawget(rawget(ItemDB, 112), "kind") == "gem"
    for _, v in ipairs(gcList or {}) do
        if type(v) == "table" then
            if not Refs.World and isWorldTable(v) then Refs.World = v end
            if not Refs.Inv and isInvTable(v) then Refs.Inv = v end
            if not gotItemDB then
                local ok, isDB = pcall(function()
                    local e112 = rawget(v, 112)
                    local e954 = rawget(v, 954)
                    return type(e112) == "table" and rawget(e112, "kind") == "gem"
                        and type(e954) == "table" and rawget(e954, "farmable") == true
                end)
                if ok and isDB then ItemDB = v gotItemDB = true end
            end
            if not Shared then
                local ok, isShared = pcall(function()
                    return typeof(rawget(v, "j1PKXTgzz")) == "Instance"
                        and type(rawget(v, "Ui")) == "table"
                end)
                if ok and isShared then Shared = v end
            end
            if not Refs.State then
                local ok, isHolder = pcall(isStateHolder, v)
                if ok and isHolder then Refs.State = rawget(v, "state") end
            end
        end
        if Refs.World and Refs.Inv and Refs.State and gotItemDB and Shared then break end
    end
    if Shared and Net == nil then
        local okN, mod = pcall(require, rawget(Shared, "j1PKXTgzz"))
        if okN and type(mod) == "table" and type(rawget(mod, "drop")) == "table"
            and type(rawget(mod, "spin")) == "table"
            and type(rawget(mod, "call")) == "function" then
            Net = mod
        end
    end
    if not gotItemDB and Shared then
        local okI, mod = pcall(require, rawget(Shared, "RnyflzPbj74"))
        if okI and type(mod) == "table" then
            local e112 = rawget(mod, 112)
            if type(e112) == "table" and rawget(e112, "kind") == "gem" then
                ItemDB = mod
            end
        end
    end
    return Refs.World ~= nil and Refs.Inv ~= nil and Net ~= nil
end

local function itemName(id)
    local it = ItemDB[id]
    if type(it) == "table" then return it.name or ("Item #" .. tostring(id)) end
    return "Item #" .. tostring(id)
end

local function invCount(id)
    if not Refs.Inv then return 0 end
    local ok, n = pcall(function() return Refs.Inv:count(id) end)
    if ok and type(n) == "number" then return n end
    local total = 0
    local ok2, slots = pcall(function() return Refs.Inv.slots end)
    if ok2 and type(slots) == "table" then
        for _, slot in ipairs(slots) do
            if type(slot) == "table" and slot.id == id then
                total = total + (slot.n or 0)
            end
        end
    end
    return total
end

local function playerState()
    if not Refs.State then return nil end
    local ok, s = pcall(Refs.State)
    if ok and type(s) == "table" and type(s.x) == "number" then return s end
    return nil
end

-- Cari tile Roulette Wheel (758) terdekat dari pemain.
local function findWheelTile()
    local w = Refs.World
    if not w or type(w.fg) ~= "table" then return nil end
    local s = playerState()
    local best = nil
    local bestD = nil
    for y, row in pairs(w.fg) do
        if type(row) == "table" then
            for x, id in pairs(row) do
                if id == WHEEL_ID then
                    local d = 9999
                    if s then
                        local dx = x - s.x
                        local dy = y - s.y
                        d = math.sqrt(dx * dx + dy * dy)
                    else
                        d = 0
                    end
                    if bestD == nil or d < bestD then
                        bestD = d
                        best = { x = x, y = y, dist = d }
                    end
                end
            end
        end
    end
    return best
end

local function dropItem(id, n)
    local w = Refs.World
    if not w or type(rawget(w, "dropOk")) ~= "function" then
        log("drop gagal: World.dropOk tidak ketemu")
        return false
    end
    if Net == nil or type(Net.drop) ~= "table" or type(Net.drop.send) ~= "function" then
        log("drop gagal: Net.drop tidak ketemu")
        return false
    end
    local s = playerState()
    if not s then
        log("drop gagal: posisi pemain tidak ketemu")
        return false
    end
    local dir = (s.facing == -1) and -1 or 1
    local dx = s.x + dir * 0.75
    local dy = s.y - 0.45
    local okDrop = false
    pcall(function() okDrop = w.dropOk(dx) end)
    if not okDrop then
        log("drop ditolak dropOk di (" .. tostring(math.floor(dx)) .. "," .. tostring(math.floor(dy)) .. ")")
        return false
    end
    if (os.clock() - (w.lastDropAt or 0)) < 0.3 then
        task.wait(0.3 - (os.clock() - (w.lastDropAt or 0)))
    end
    local okSend = pcall(Net.drop.send, { id = id, n = n, x = dx, y = dy })
    if not okSend then
        log("drop gagal: Net.drop.send error")
        return false
    end
    pcall(function() w.lastDropAt = os.clock() end)
    if Refs.Inv then pcall(function() Refs.Inv:remove(id, n) end) end
    return true
end

local lastSpinAt = 0
local lastSpinKey = ""
local function spinWheel(tx, ty)
    if Net == nil or type(Net.spin) ~= "table" or type(Net.spin.send) ~= "function" then
        log("spin gagal: Net.spin tidak ketemu")
        return false
    end
    local key = tostring(tx) .. "," .. tostring(ty)
    if key == lastSpinKey and (os.clock() - lastSpinAt) < 0.6 then
        task.wait(0.6 - (os.clock() - lastSpinAt))
    end
    local okSend = pcall(Net.spin.send, { x = tx, y = ty })
    if not okSend then
        log("spin gagal: Net.spin.send error")
        return false
    end
    lastSpinAt = os.clock()
    lastSpinKey = key
    return true
end

-- Log hasil spin dari server (best-effort; hasil juga muncul di chat game).
local function listenWheelSpun()
    if Net ~= nil and Net.wheelSpun ~= nil and type(Net.wheelSpun.listen) == "function" then
        pcall(function()
            Net.wheelSpun.listen(function(pkt)
                if type(pkt) == "table" and pkt.name ~= nil then
                    local mine = (pkt.userId == LocalPlayer.UserId) and " (kamu)" or ""
                    log("WheelSpun: " .. tostring(pkt.n) .. "x " .. tostring(pkt.name)
                        .. " di (" .. tostring(pkt.x) .. "," .. tostring(pkt.y) .. ")" .. mine)
                end
            end)
        end)
        return
    end
    local w = Refs.World
    if w and type(rawget(w, "on")) == "function" then
        pcall(function()
            w.on("WheelSpun", function(...)
                local a = { ... }
                local pkt = nil
                if type(a[1]) == "table" then
                    pkt = a[1]
                else
                    pkt = { x = a[1], y = a[2], n = a[3], name = a[4], userId = a[5] }
                end
                if type(pkt) == "table" and pkt.name ~= nil then
                    log("WheelSpun: " .. tostring(pkt.n) .. "x " .. tostring(pkt.name))
                end
            end)
        end)
    end
end

-- ---------- connect + main loop ----------
log("connecting... item=" .. itemName(ITEM_ID) .. " (" .. ITEM_ID .. ") x" .. DROP_COUNT)
local okRefs = pcall(findRefs)
log("refs: World=" .. tostring(Refs.World ~= nil)
    .. " Inv=" .. tostring(Refs.Inv ~= nil)
    .. " Net=" .. tostring(Net ~= nil)
    .. " State=" .. tostring(Refs.State ~= nil))
if not okRefs or Refs.World == nil or Refs.Inv == nil or Net == nil then
    log("STOP: refs tidak lengkap. Re-execute di world Growblox (Delta).")
    return
end
listenWheelSpun()

local cycle = 0
while true do
    if MAX_CYCLES > 0 and cycle >= MAX_CYCLES then
        log("stop: MAX_CYCLES tercapai (" .. MAX_CYCLES .. ")")
        break
    end
    local have = invCount(ITEM_ID)
    if have < DROP_COUNT then
        log("stop: sisa " .. itemName(ITEM_ID) .. " " .. have .. " < " .. DROP_COUNT)
        break
    end
    local wheel = findWheelTile()
    if wheel == nil then
        log("stop: tidak ada Roulette Wheel (758) di world ini")
        break
    end
    if wheel.dist > MAX_SPIN_DIST then
        log("peringatan: wheel terdekat di (" .. wheel.x .. "," .. wheel.y .. "), jarak "
            .. string.format("%.1f", wheel.dist) .. " tile — berdiri lebih dekat, spin bisa diabaikan server")
    end
    local okDrop = dropItem(ITEM_ID, DROP_COUNT)
    if okDrop then
        log("cycle " .. (cycle + 1) .. ": dropped " .. itemName(ITEM_ID) .. " x" .. DROP_COUNT)
    end
    task.wait(DROP_DELAY)
    local okSpin = spinWheel(wheel.x, wheel.y)
    if okSpin then
        log("cycle " .. (cycle + 1) .. ": spin wheel (" .. wheel.x .. "," .. wheel.y .. ")")
    end
    task.wait(SPIN_DELAY)
    cycle = cycle + 1
end

log("selesai, total cycle: " .. cycle)
