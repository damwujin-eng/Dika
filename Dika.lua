-- GROWBLOX ITEM DUPLICATOR
-- Inventory simulation for Roblox Studio
-- Does not modify public Growblox servers.

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local inventory = {
    {
        id = "ITEM-001",
        name = "Test Item",
        amount = 1
    }
}

local function create(class, properties, parent)
    local object = Instance.new(class)

    for property, value in pairs(properties) do
        object[property] = value
    end

    object.Parent = parent
    return object
end

local gui = create("ScreenGui", {
    Name = "GrowbloxDuplicator",
    ResetOnSpawn = false
}, player:WaitForChild("PlayerGui"))

local frame = create("Frame", {
    Size = UDim2.fromOffset(320, 300),
    Position = UDim2.new(0.5, -160, 0.5, -150),
    BackgroundColor3 = Color3.fromRGB(20, 25, 22),
    BorderSizePixel = 0
}, gui)

create("UICorner", {
    CornerRadius = UDim.new(0, 12)
}, frame)

local title = create("TextLabel", {
    Size = UDim2.new(1, 0, 0, 45),
    BackgroundTransparency = 1,
    Text = "GROWBLOX ITEM DUPLICATOR",
    TextColor3 = Color3.fromRGB(0, 255, 120),
    TextSize = 17,
    Font = Enum.Font.GothamBold
}, frame)

local itemName = create("TextLabel", {
    Position = UDim2.fromOffset(15, 60),
    Size = UDim2.new(1, -30, 0, 30),
    BackgroundTransparency = 1,
    Text = "Selected: Test Item",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Font = Enum.Font.Gotham
}, frame)

local amount = create("TextBox", {
    Position = UDim2.fromOffset(20, 105),
    Size = UDim2.new(1, -40, 0, 40),
    BackgroundColor3 = Color3.fromRGB(35, 45, 38),
    TextColor3 = Color3.new(1, 1, 1),
    PlaceholderText = "Enter amount",
    Text = "1",
    TextSize = 16,
    Font = Enum.Font.GothamBold,
    ClearTextOnFocus = false
}, frame)

create("UICorner", {
    CornerRadius = UDim.new(0, 8)
}, amount)

local duplicate = create("TextButton", {
    Position = UDim2.fromOffset(20, 160),
    Size = UDim2.new(1, -40, 0, 42),
    BackgroundColor3 = Color3.fromRGB(0, 180, 85),
    Text = "DUPLICATE",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 16,
    Font = Enum.Font.GothamBold
}, frame)

create("UICorner", {
    CornerRadius = UDim.new(0, 8)
}, duplicate)

local clear = create("TextButton", {
    Position = UDim2.fromOffset(20, 210),
    Size = UDim2.new(1, -40, 0, 35),
    BackgroundColor3 = Color3.fromRGB(160, 45, 45),
    Text = "CLEAR INVENTORY",
    TextColor3 = Color3.new(1, 1, 1),
    TextSize = 14,
    Font = Enum.Font.GothamBold
}, frame)

create("UICorner", {
    CornerRadius = UDim.new(0, 8)
}, clear)

local status = create("TextLabel", {
    Position = UDim2.fromOffset(10, 255),
    Size = UDim2.new(1, -20, 0, 30),
    BackgroundTransparency = 1,
    Text = "Ready - Simulation Mode",
    TextColor3 = Color3.fromRGB(0, 255, 120),
    TextSize = 12,
    Font = Enum.Font.Gotham
}, frame)

duplicate.MouseButton1Click:Connect(function()
    local count = tonumber(amount.Text)

    if not count or count < 1 or count > 100 then
        status.Text = "Invalid amount (1-100)"
        return
    end

    for i = 1, count do
        table.insert(inventory, {
            id = "COPY-" .. game:GetService("HttpService"):GenerateGUID(false),
            name = "Test Item",
            amount = 1
        })
    end

    status.Text = "Created " .. count .. " simulated items!"
end)

clear.MouseButton1Click:Connect(function()
    table.clear(inventory)

    status.Text = "Simulation inventory cleared!"
end)
