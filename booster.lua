local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

Lighting.GlobalShadows = false
Lighting.FogEnd = 9e9
Lighting.ShadowMapDisplayDistance = 0
settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
settings().Network.IncomingReplicationLag = 0
if setfpscap then setfpscap(120) end

local function boost(obj)
    if obj:IsA("BasePart") or obj:IsA("MeshPart") or obj:IsA("Part") then
        obj.CastShadow = false
        obj.Reflectance = 0
        obj.Material = Enum.Material.SmoothPlastic
    elseif obj:IsA("Texture") or obj:IsA("Decal") then
        obj:Destroy()
    elseif obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Sparkles") or obj:IsA("Fire") then
        obj.Enabled = false
    elseif obj:IsA("PostEffect") or obj:IsA("BloomEffect") or obj:IsA("BlurEffect") or obj:IsA("DepthOfFieldEffect") or obj:IsA("SunRaysEffect") then
        obj.Enabled = false
    elseif obj:IsA("Terrain") then
        obj.WaterWaveSize = 0
        obj.WaterWaveSpeed = 0
        obj.WaterReflectance = 0
        obj.WaterTransparency = 0
        obj.Decoration = false
    end
end

for _, v in ipairs(game:GetDescendants()) do pcall(boost, v) end
game.DescendantAdded:Connect(function(v) pcall(boost, v) end)

task.spawn(function()
    while task.wait(15) do collectgarbage("collect") end
end)

local function createWatermark()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end
    
    local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
    if not playerGui then return end
    
    -- Проверка на то, существует ли уже рабочий GUI
    local existingGui = playerGui:FindFirstChild("v3xo_Watermark")
    if existingGui and existingGui:FindFirstChild("WatermarkText") then 
        return 
    elseif existingGui then
        existingGui:Destroy() -- Очистка сломанного контейнера
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "v3xo_Watermark"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 9999
    
    local label = Instance.new("TextLabel")
    label.Name = "WatermarkText"
    label.Size = UDim2.new(0, 200, 0, 50)
    
    -- Смещение к кнопке прыжка для мобильных экранов
    label.Position = UDim2.new(1, -150, 1, -120) 
    label.AnchorPoint = Vector2.new(0.5, 0.5)
    
    label.Text = "v3xo"
    label.Font = Enum.Font.GothamBold
    label.TextSize = 28
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextTransparency = 0.5
    
    label.BackgroundTransparency = 1
    label.Active = false
    label.Selectable = false
    
    label.Parent = screenGui
    screenGui.Parent = playerGui
end

-- Безопасный бесконечный цикл проверки видимости текста
task.spawn(function()
    while true do
        pcall(createWatermark)
        task.wait(1)
    end
end)
