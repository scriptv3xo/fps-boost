local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- === OPTIMIZATION: Cache frequently accessed values ===
local GetService = game.GetService
local Vector2New = Vector2.new
local Vector3New = Vector3.new
local Color3New = Color3.new
local Color3RGB = Color3.fromRGB
local UDim2New = UDim2.new
local math_clamp = math.clamp
local math_floor = math.floor

-- Database для ролей MM2
local MM2_Roles = {Murderer = nil, Sheriff = nil, Hero = nil}

-- Полная конфигурация со всеми функциями
local Config = {
    ESP = {
        Enabled = false,
        Boxes = false,
        Names = false,
        TeamCheck = false,
        Color = Color3RGB(186, 85, 211),
        Silent = true  -- No logging/loading on ESP enable
    },
    MM2 = {
        RoleESP = false,
        GunESP = false,
        RoleNotifier = false,
        KillAura = false,
        KillAuraRange = 15,
        GrabGun = false,
        MapInf = false,
        ShowInfoPanel = false
    },
    Misc = {
        WalkSpeedEnabled = false,
        WalkSpeedValue = 50,
        JumpPowerEnabled = false,
        JumpPowerValue = 100,
        InfiniteJump = false,
        Noclip = false,
        Fly = false,
        FlySpeed = 50
    },
    Features = {
        HolographicESP = false,
        SilentMode = true
    }
}

-- ==========================================
-- СИСТЕМА СОХРАНЕНИЯ / ЗАГРУЗКИ КОНФИГА
-- ==========================================
local ConfigFileName = "v3xo_mm2_config.json"

local function SaveConfig()
    if writefile then
        local success, encoded = pcall(function()
            local cfgCopy = HttpService:JSONDecode(HttpService:JSONEncode(Config))
            cfgCopy.ESP.Color = {Config.ESP.Color.R, Config.ESP.Color.G, Config.ESP.Color.B}
            return HttpService:JSONEncode(cfgCopy)
        end)
        if success then
            writefile(ConfigFileName, encoded)
        end
    end
end

local function LoadConfig()
    if readfile and isfile and isfile(ConfigFileName) then
        local success, decoded = pcall(function()
            return HttpService:JSONDecode(readfile(ConfigFileName))
        end)
        if success and decoded then
            for category, sub in pairs(decoded) do
                if Config[category] then
                    for key, val in pairs(sub) do
                        if key ~= "Color" then
                            Config[category][key] = val
                        end
                    end
                end
            end
            if decoded.ESP and decoded.ESP.Color then
                Config.ESP.Color = Color3New(decoded.ESP.Color[1], decoded.ESP.Color[2], decoded.ESP.Color[3])
            end
        end
    end
end

LoadConfig()

-- === OPTIMIZATION: Create GUI container once ===
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "v3xo_MM2_Hub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

if gethui then ScreenGui.Parent = gethui()
elseif syn and syn.protect_gui then syn.protect_gui(ScreenGui) ScreenGui.Parent = CoreGui
else ScreenGui.Parent = CoreGui end

-- Универсальный Drag для мобилок (оптимизирован)
local function EnableMobileDrag(gui)
    local dragging, dragInput, dragStart, startPos
    gui.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gui.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    gui.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseBehavior or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            gui.Position = UDim2New(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

-- ==========================================
-- ИНФОРМАЦИОННАЯ ПАНЕЛЬ РОЛЕЙ
-- ==========================================
local InfoPanel = Instance.new("Frame")
local InfoCorner = Instance.new("UICorner")
local InfoStroke = Instance.new("UIStroke")
local MurdLabel = Instance.new("TextLabel")
local SherLabel = Instance.new("TextLabel")

InfoPanel.Name = "MM2_InfoPanel"
InfoPanel.Size = UDim2New(0, 240, 0, 65)
InfoPanel.Position = UDim2New(1, -260, 0, 80)
InfoPanel.BackgroundColor3 = Color3RGB(15, 10, 25)
InfoPanel.BackgroundTransparency = 0.2
InfoPanel.Visible = false
InfoPanel.Parent = ScreenGui
EnableMobileDrag(InfoPanel)

InfoCorner.CornerRadius = UDim.new(0, 8)
InfoCorner.Parent = InfoPanel

InfoStroke.Thickness = 1.5
InfoStroke.Parent = InfoPanel

MurdLabel.Size = UDim2New(1, -20, 0, 25)
MurdLabel.Position = UDim2New(0, 10, 0, 5)
MurdLabel.BackgroundTransparency = 1
MurdLabel.Font = Enum.Font.GothamBold
MurdLabel.Text = "Murderer: Checking..."
MurdLabel.TextColor3 = Color3RGB(255, 50, 50)
MurdLabel.TextSize = 13
MurdLabel.TextXAlignment = Enum.TextXAlignment.Left
MurdLabel.Parent = InfoPanel

SherLabel.Size = UDim2New(1, -20, 0, 25)
SherLabel.Position = UDim2New(0, 10, 0, 30)
SherLabel.BackgroundTransparency = 1
SherLabel.Font = Enum.Font.GothamBold
SherLabel.Text = "Sheriff: Checking..."
SherLabel.TextColor3 = Color3RGB(50, 150, 255)
SherLabel.TextSize = 13
SherLabel.TextXAlignment = Enum.TextXAlignment.Left
SherLabel.Parent = InfoPanel

-- ==========================================
-- ИНТЕРФЕЙС ГЛАВНОГО МЕНЮ
-- ==========================================
local MainFrame = Instance.new("Frame")
local MainCorner = Instance.new("UICorner")
local MainStroke = Instance.new("UIStroke")
local LeftPanel = Instance.new("Frame")
local LeftCorner = Instance.new("UICorner")
local RightPanel = Instance.new("Frame")
local Title = Instance.new("TextLabel")
local UIListLayout = Instance.new("UIListLayout")

MainFrame.Name = "MainHubFrame"
MainFrame.Size = UDim2New(0, 560, 0, 360)
MainFrame.Position = UDim2New(0.5, -280, 0.5, -180)
MainFrame.BackgroundColor3 = Color3RGB(15, 10, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui
EnableMobileDrag(MainFrame)

MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

MainStroke.Thickness = 2.5
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.LineJoinMode = Enum.LineJoinMode.Round
MainStroke.Parent = MainFrame

LeftPanel.Size = UDim2New(0, 140, 1, 0)
LeftPanel.BackgroundColor3 = Color3RGB(10, 5, 18)
LeftPanel.BorderSizePixel = 0
LeftPanel.Parent = MainFrame

LeftCorner.CornerRadius = UDim.new(0, 10)
LeftCorner.Parent = LeftPanel

Title.Size = UDim2New(1, 0, 0, 45)
Title.BackgroundTransparency = 1
Title.Font = Enum.Font.GothamBold
Title.Text = "@v3xo"
Title.TextColor3 = Color3RGB(220, 130, 255)
Title.TextSize = 22
Title.Parent = LeftPanel

UIListLayout.Parent = LeftPanel
UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UIListLayout.Padding = UDim.new(0, 6)

RightPanel.Size = UDim2New(1, -140, 1, 0)
RightPanel.Position = UDim2New(0, 140, 0, 0)
RightPanel.BackgroundTransparency = 1
RightPanel.Parent = MainFrame

local ToggleButton = Instance.new("TextButton")
local ToggleCorner = Instance.new("UICorner")
local ToggleStroke = Instance.new("UIStroke")

ToggleButton.Name = "MobileToggleBtn"
ToggleButton.Size = UDim2New(0, 55, 0, 55)
ToggleButton.Position = UDim2New(0, 15, 0, 15)
ToggleButton.BackgroundColor3 = Color3RGB(30, 15, 45)
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.Text = "V"
ToggleButton.TextColor3 = Color3RGB(230, 150, 255)
ToggleButton.TextSize = 20
ToggleButton.Parent = ScreenGui
EnableMobileDrag(ToggleButton)

ToggleCorner.CornerRadius = UDim.new(1, 0)
ToggleCorner.Parent = ToggleButton

ToggleStroke.Thickness = 2
ToggleStroke.Parent = ToggleButton

ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
    ToggleButton.Text = MainFrame.Visible and "V" or "@"
end)

-- === OPTIMIZATION: Rainbow effect on separate task with lower frequency ===
task.spawn(function()
    while task.wait(0.016) do  -- ~60fps for visual effects
        local hue = (tick() % 4) / 4
        local rainbowColor = Color3.fromHSV(hue, 0.8, 1)
        MainStroke.Color = rainbowColor
        ToggleStroke.Color = rainbowColor
        InfoStroke.Color = rainbowColor
    end
end)

-- Создание структуры вкладок хаба
local Tabs = {}
local function CreateTabContainer(name)
    local Container = Instance.new("ScrollingFrame")
    Container.Name = name .. "Tab"
    Container.Size = UDim2New(1, -20, 1, -20)
    Container.Position = UDim2New(0, 10, 0, 10)
    Container.BackgroundTransparency = 1
    Container.CanvasSize = UDim2New(0, 0, 2.2, 0)
    Container.ScrollBarThickness = 3
    Container.ScrollBarImageColor3 = Color3RGB(186, 85, 211)
    Container.Visible = false
    Container.Parent = RightPanel

    local List = Instance.new("UIListLayout")
    List.Parent = Container
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Padding = UDim.new(0, 8)

    Tabs[name] = Container
    return Container
end

local ESPTab = CreateTabContainer("ESP")
local MM2Tab = CreateTabContainer("MM2")
local FeaturesTab = CreateTabContainer("Features")
local MiscTab = CreateTabContainer("Misc")
Tabs["ESP"].Visible = true

local function AddTabButton(name)
    local Button = Instance.new("TextButton")
    Button.Size = UDim2New(1, -12, 0, 36)
    Button.Position = UDim2New(0, 6, 0, 0)
    Button.BackgroundColor3 = Color3RGB(22, 14, 35)
    Button.Font = Enum.Font.GothamMedium
    Button.Text = name
    Button.TextColor3 = Color3RGB(180, 160, 200)
    Button.TextSize = 14
    Button.Parent = LeftPanel

    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.CornerRadius = UDim.new(0, 6)
    ButtonCorner.Parent = Button

    Button.MouseButton1Click:Connect(function()
        for tabName, container in pairs(Tabs) do
            container.Visible = (tabName == name)
        end
    end)
end

AddTabButton("ESP")
AddTabButton("MM2")
AddTabButton("Features")
AddTabButton("Misc")

-- === OPTIMIZATION: Create UI elements more efficiently ===
local function CreateToggle(parent, text, initial, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2New(1, -10, 0, 32)
    Frame.BackgroundTransparency = 1
    Frame.Parent = parent

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2New(0.7, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.Gotham
    Label.Text = text
    Label.TextColor3 = Color3RGB(240, 230, 255)
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local Button = Instance.new("TextButton")
    Button.Size = UDim2New(0, 55, 0, 24)
    Button.Position = UDim2New(1, -60, 0, 4)
    Button.BackgroundColor3 = initial and Color3RGB(186, 85, 211) or Color3RGB(35, 25, 45)
    Button.Text = initial and "ON" or "OFF"
    Button.TextColor3 = initial and Color3RGB(255, 255, 255) or Color3RGB(140, 120, 160)
    Button.Font = Enum.Font.GothamBold
    Button.TextSize = 12
    Button.Parent = Frame

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 5)
    BtnCorner.Parent = Button

    local state = initial
    Button.MouseButton1Click:Connect(function()
        state = not state
        Button.BackgroundColor3 = state and Color3RGB(186, 85, 211) or Color3RGB(35, 25, 45)
        Button.TextColor3 = state and Color3RGB(255, 255, 255) or Color3RGB(140, 120, 160)
        Button.Text = state and "ON" or "OFF"
        callback(state)
        SaveConfig()
    end)
end

local function CreateModeSelector(parent, text, modes, default, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2New(1, -10, 0, 32)
    Frame.BackgroundTransparency = 1
    Frame.Parent = parent

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2New(0.5, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.Gotham
    Label.Text = text
    Label.TextColor3 = Color3RGB(240, 230, 255)
    Label.TextSize = 14
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local Button = Instance.new("TextButton")
    Button.Size = UDim2New(0, 90, 0, 24)
    Button.Position = UDim2New(1, -95, 0, 4)
    Button.BackgroundColor3 = Color3RGB(35, 25, 45)
    Button.Text = default
    Button.TextColor3 = Color3RGB(230, 150, 255)
    Button.Font = Enum.Font.GothamBold
    Button.TextSize = 12
    Button.Parent = Frame

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 5)
    BtnCorner.Parent = Button

    local currentIdx = 1
    for i, v in ipairs(modes) do if v == default then currentIdx = i break end end
    Button.MouseButton1Click:Connect(function()
        currentIdx = currentIdx % #modes + 1
        Button.Text = modes[currentIdx]
        callback(modes[currentIdx])
        SaveConfig()
    end)
end

local function CreateSlider(parent, text, min, max, default, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2New(1, -10, 0, 45)
    Frame.BackgroundTransparency = 1
    Frame.Parent = parent

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2New(1, 0, 0, 20)
    Label.BackgroundTransparency = 1
    Label.Font = Enum.Font.Gotham
    Label.Text = text .. ": " .. tostring(default)
    Label.TextColor3 = Color3RGB(240, 230, 255)
    Label.TextSize = 12
    Label.TextXAlignment = Enum.TextXAlignment.Left
    Label.Parent = Frame

    local SliderBar = Instance.new("TextButton")
    SliderBar.Size = UDim2New(1, 0, 0, 8)
    SliderBar.Position = UDim2New(0, 0, 0, 23)
    SliderBar.BackgroundColor3 = Color3RGB(35, 25, 45)
    SliderBar.Text = ""
    SliderBar.Parent = Frame

    local Fill = Instance.new("Frame")
    Fill.Size = UDim2New((default - min) / (max - min), 0, 1, 0)
    Fill.BackgroundColor3 = Color3RGB(186, 85, 211)
    Fill.BorderSizePixel = 0
    Fill.Parent = SliderBar

    local function update(input)
        local pos = math_clamp((input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
        Fill.Size = UDim2New(pos, 0, 1, 0)
        local value = math_floor(min + (max - min) * pos)
        Label.Text = text .. ": " .. tostring(value)
        callback(value)
        SaveConfig()
    end

    local sliding = false
    SliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = true update(input) end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then update(input) end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then sliding = false end
    end)
end

-- Сборка элементов управления по вкладкам
-- ESP вкладка
CreateToggle(ESPTab, "Master Switch ESP", Config.ESP.Enabled, function(v) Config.ESP.Enabled = v end)
CreateToggle(ESPTab, "Chams / Boxes", Config.ESP.Boxes, function(v) Config.ESP.Boxes = v end)
CreateToggle(ESPTab, "Player Names Tag", Config.ESP.Names, function(v) Config.ESP.Names = v end)
CreateToggle(ESPTab, "Silent Mode (No Logs)", Config.ESP.Silent, function(v) Config.ESP.Silent = v end)

-- MM2 вкладка
CreateToggle(MM2Tab, "MM2 Role Wallhack (Chams)", Config.MM2.RoleESP, function(v) Config.MM2.RoleESP = v end)
CreateToggle(MM2Tab, "Dropped Gun ESP", Config.MM2.GunESP, function(v) Config.MM2.GunESP = v end)
CreateToggle(MM2Tab, "Role Notifier Overlay", Config.MM2.RoleNotifier, function(v) Config.MM2.RoleNotifier = v end)
CreateToggle(MM2Tab, "Show Info Panel (Roles)", Config.MM2.ShowInfoPanel, function(v) Config.MM2.ShowInfoPanel = v InfoPanel.Visible = v end)
CreateToggle(MM2Tab, "Auto Grab Gun", Config.MM2.GrabGun, function(v) Config.MM2.GrabGun = v end)
CreateToggle(MM2Tab, "Murderer Kill Aura", Config.MM2.KillAura, function(v) Config.MM2.KillAura = v end)
CreateSlider(MM2Tab, "Kill Aura Range", 5, 30, Config.MM2.KillAuraRange, function(v) Config.MM2.KillAuraRange = v end)
CreateToggle(MM2Tab, "Map Visual Improvements", Config.MM2.MapInf, function(v) Config.MM2.MapInf = v end)

-- Features вкладка - What a cool tab!
CreateToggle(FeaturesTab, "Holographic ESP Effect", Config.Features.HolographicESP, function(v) Config.Features.HolographicESP = v end)
CreateToggle(FeaturesTab, "Silent Mode Active", Config.Features.SilentMode, function(v) Config.Features.SilentMode = v end)

-- Misc вкладка
CreateToggle(MiscTab, "Super Speed Mode", Config.Misc.WalkSpeedEnabled, function(v) Config.Misc.WalkSpeedEnabled = v end)
CreateSlider(MiscTab, "Speed Multiplier", 16, 200, Config.Misc.WalkSpeedValue, function(v) Config.Misc.WalkSpeedValue = v end)
CreateToggle(MiscTab, "High Jump Power", Config.Misc.JumpPowerEnabled, function(v) Config.Misc.JumpPowerEnabled = v end)
CreateSlider(MiscTab, "Jump Altitude", 50, 300, Config.Misc.JumpPowerValue, function(v) Config.Misc.JumpPowerValue = v end)
CreateToggle(MiscTab, "Infinite Mid-Air Jump", Config.Misc.InfiniteJump, function(v) Config.Misc.InfiniteJump = v end)
CreateToggle(MiscTab, "Noclip Walls Phase", Config.Misc.Noclip, function(v) Config.Misc.Noclip = v end)
CreateToggle(MiscTab, "Fly Mode Controller", Config.Misc.Fly, function(v) Config.Misc.Fly = v end)

-- ==========================================
-- ЛОГИКА ДЛЯ ИГРЫ MURDER MYSTERY 2 (ОПТИМИЗИРОВАНА)
-- ==========================================

local RoleLabel = Instance.new("TextLabel")
RoleLabel.Size = UDim2New(0, 400, 0, 60)
RoleLabel.Position = UDim2New(0.5, -200, 0.15, 0)
RoleLabel.BackgroundTransparency = 1
RoleLabel.Font = Enum.Font.GothamBold
RoleLabel.TextSize = 16
RoleLabel.TextColor3 = Color3RGB(255, 255, 255)
RoleLabel.Text = ""
RoleLabel.Visible = false
RoleLabel.Parent = ScreenGui

-- === OPTIMIZATION: Cache MM2 detection every 1 second instead of every frame ===
local lastRoleUpdateTime = 0
local function GetMM2Roles()
    local currentTime = tick()
    if currentTime - lastRoleUpdateTime < 1 then return end
    lastRoleUpdateTime = currentTime

    MM2_Roles.Murderer = nil
    MM2_Roles.Sheriff = nil
    MM2_Roles.Hero = nil
    
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character then
            if p.Backpack:FindFirstChild("Knife") or p.Character:FindFirstChild("Knife") then
                MM2_Roles.Murderer = p
            elseif p.Backpack:FindFirstChild("Gun") or p.Character:FindFirstChild("Gun") then
                MM2_Roles.Sheriff = p
            end
        end
    end
    
    if Config.MM2.ShowInfoPanel then
        MurdLabel.Text = "Murderer: " .. (MM2_Roles.Murderer and MM2_Roles.Murderer.Name or "Hidden / Dead")
        SherLabel.Text = "Sheriff: " .. (MM2_Roles.Sheriff and MM2_Roles.Sheriff.Name or "Hidden / No Gun")
    end
end

-- Обработка уведомлений о ролях (ОПТИМИЗИРОВАНО)
task.spawn(function()
    while task.wait(1) do
        GetMM2Roles()
        if Config.MM2.RoleNotifier then
            local txt = ""
            if MM2_Roles.Murderer then txt = txt .. "[Murderer]: " .. MM2_Roles.Murderer.Name .. " 🔥\n" end
            if MM2_Roles.Sheriff then txt = txt .. "[Sheriff]: " .. MM2_Roles.Sheriff.Name .. " 🎯" end
            RoleLabel.Visible = txt ~= ""
            RoleLabel.Text = txt
        else
            RoleLabel.Visible = false
        end
    end
end)

-- === OPTIMIZATION: Auto Gun Grab - reduced frequency ===
task.spawn(function()
    while task.wait(0.5) do
        if Config.MM2.GrabGun and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            local gunDrop = workspace:FindFirstChild("GunDrop") or workspace:FindFirstChild("Gun")
            if gunDrop and gunDrop:IsA("BasePart") then
                LocalPlayer.Character.HumanoidRootPart.CFrame = gunDrop.CFrame
            end
        end
    end
end)

-- === OPTIMIZATION: Map improvements - reduced frequency to 3s ===
task.spawn(function()
    while task.wait(3) do
        if Config.MM2.MapInf then
            local env = workspace:FindFirstChild("Normal") or workspace:FindFirstChild("Geometry") or workspace
            local descendantCount = 0
            for _, item in pairs(env:GetDescendants()) do
                descendantCount = descendantCount + 1
                if descendantCount > 500 then break end
                if item:IsA("BasePart") and item.Transparency < 0.2 and not item:IsDescendantOf(LocalPlayer.Character) then
                    item.Transparency = 0.4
                end
            end
        end
    end
end)

-- === OPTIMIZATION: Kill Aura - reduced frequency to 0.15s ===
task.spawn(function()
    while task.wait(0.15) do
        if Config.MM2.KillAura and MM2_Roles.Murderer == LocalPlayer and LocalPlayer.Character then
            local knife = LocalPlayer.Character:FindFirstChild("Knife") or LocalPlayer.Backpack:FindFirstChild("Knife")
            if knife then
                if knife.Parent ~= LocalPlayer.Character then
                    knife.Parent = LocalPlayer.Character
                end
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                        local dist = (player.Character.HumanoidRootPart.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude
                        local hum = player.Character:FindFirstChildOfClass("Humanoid")
                        if dist <= Config.MM2.KillAuraRange and hum and hum.Health > 0 then
                            knife:Activate()
                            if firetouchinterest then
                                firetouchinterest(player.Character.HumanoidRootPart, knife.Handle, 0)
                                firetouchinterest(player.Character.HumanoidRootPart, knife.Handle, 1)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- ESP СИСТЕМА (ОПТИМИЗИРОВАНА - NO LOGGING)
-- ==========================================
local function SetupESPForPlayer(player)
    if player == LocalPlayer then return end
    
    local function initCharacter(char)
        task.wait(0.5)
        if not char:IsDescendantOf(workspace) then return end
        if char:FindFirstChild("v3xo_Highlight") then char["v3xo_Highlight"]:Destroy() end
        if char:FindFirstChild("v3xo_Billboard") then char["v3xo_Billboard"]:Destroy() end

        local highlight = Instance.new("Highlight")
        highlight.Name = "v3xo_Highlight"
        highlight.FillTransparency = Config.Features.HolographicESP and 0.2 or 0.4
        highlight.OutlineColor = Color3RGB(255, 255, 255)
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Enabled = false
        highlight.Parent = char

        local head = char:WaitForChild("Head", 5)
        if head then
            local billboard = Instance.new("BillboardGui")
            billboard.Name = "v3xo_Billboard"
            billboard.Size = UDim2New(0, 200, 0, 50)
            billboard.AlwaysOnTop = true
            billboard.ExtentsOffset = Vector3New(0, 2.5, 0)
            billboard.Enabled = false

            local label = Instance.new("TextLabel")
            label.Size = UDim2New(1, 0, 1, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = Color3RGB(255, 255, 255)
            label.TextStrokeTransparency = 0
            label.Font = Enum.Font.GothamBold
            label.TextSize = 14
            label.Text = player.Name
            label.Parent = billboard
            billboard.Parent = char
        end
    end
    player.CharacterAdded:Connect(initCharacter)
    if player.Character then task.spawn(initCharacter, player.Character) end
end

Players.PlayerAdded:Connect(SetupESPForPlayer)
for _, p in pairs(Players:GetPlayers()) do SetupESPForPlayer(p) end

-- === OPTIMIZATION: ESP Update on RenderStepped (more efficient than Heartbeat) ===
local espUpdateCounter = 0
RunService.RenderStepped:Connect(function()
    espUpdateCounter = espUpdateCounter + 1
    if espUpdateCounter % 2 ~= 0 then return end

    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local char = player.Character
            local hl = char:FindFirstChild("v3xo_Highlight")
            local bb = char:FindFirstChild("v3xo_Billboard")
            
            local showBasic = Config.ESP.Enabled
            local showRoles = Config.MM2.RoleESP
            
            if hl then
                hl.Enabled = (showBasic and Config.ESP.Boxes) or showRoles
                if showRoles then
                    if player == MM2_Roles.Murderer then
                        hl.FillColor = Color3RGB(255, 0, 0)
                    elseif player == MM2_Roles.Sheriff then
                        hl.FillColor = Color3RGB(0, 0, 255)
                    else
                        hl.FillColor = Color3RGB(0, 255, 0)
                    end
                else
                    hl.FillColor = Config.ESP.Color
                end
            end

            if bb then
                bb.Enabled = (showBasic and Config.ESP.Names) or showRoles
                local label = bb:FindFirstChildOfClass("TextLabel")
                if label then
                    if showRoles and player == MM2_Roles.Murderer then
                        label.Text = "[MURDERER] " .. player.Name
                        label.TextColor3 = Color3RGB(255, 0, 0)
                    elseif showRoles and player == MM2_Roles.Sheriff then
                        label.Text = "[SHERIFF] " .. player.Name
                        label.TextColor3 = Color3RGB(0, 150, 255)
                    else
                        label.Text = player.Name
                        label.TextColor3 = Color3RGB(255, 255, 255)
                    end
                end
            end
        end
    end

    -- Gun ESP
    local gunDrop = workspace:FindFirstChild("GunDrop")
    if gunDrop and Config.MM2.GunESP then
        local gunHl = gunDrop:FindFirstChild("v3xo_GunHighlight")
        if not gunHl then
            gunHl = Instance.new("Highlight")
            gunHl.Name = "v3xo_GunHighlight"
            gunHl.FillColor = Color3RGB(255, 215, 0)
            gunHl.OutlineColor = Color3RGB(255, 255, 255)
            gunHl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            gunHl.Parent = gunDrop
        end
        gunHl.Enabled = true
    elseif gunDrop and not Config.MM2.GunESP and gunDrop:FindFirstChild("v3xo_GunHighlight") then
        gunDrop["v3xo_GunHighlight"].Enabled = false
    end
end)

-- ==========================================
-- MISC FEATURES (ОПТИМИЗИРОВАНА)
-- ==========================================
local noclipCounter = 0
RunService.Stepped:Connect(function()
    noclipCounter = noclipCounter + 1
    if Config.Misc.Noclip and noclipCounter % 2 == 0 and LocalPlayer.Character then
        for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
            if part:IsA("BasePart") then part.CanCollide = false end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if Config.Misc.WalkSpeedEnabled then hum.WalkSpeed = Config.Misc.WalkSpeedValue end
        if Config.Misc.JumpPowerEnabled then 
            hum.UseJumpPower = true 
            hum.JumpPower = Config.Misc.JumpPowerValue 
        end
    end
    
    if Config.Misc.Fly and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = LocalPlayer.Character.HumanoidRootPart
        local hum = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then
            hrp.Velocity = hum.MoveDirection * Config.Misc.FlySpeed + Vector3New(0, 0.5, 0)
        end
    end
end)

UserInputService.JumpRequest:Connect(function()
    if Config.Misc.InfiniteJump and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

print("✅ @v3xo MM2 Hub - Enhanced Edition Loaded!")
print("⚡ Features: ESP | MM2 Tools | Misc Utilities")
print("🎯 What a cool tab! Features panel is ready to explore!")
