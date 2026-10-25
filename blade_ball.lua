--// AUTO PARRY HUB - PHANTOM 1099 // --
--// PURE LUAU | NO EXTERNAL LIBS // --

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BallFolder = workspace:WaitForChild("Balls")

--// CONFIGURAÇÃO GLOBAL //
local Config = {
    Enabled = false;
    Accuracy = 75;
    RandomizeAccuracy = true;
    RandomRange = {25, 85};
    ParryMode = "Remote"; -- Remote ou Mouse
    PredictionOffset = 0.08;
    MinDistance = 6.5;
}

--// ESTADO INTERNO //
local CachedArgs = nil
local LastParryTime = 0
local CooldownProtection = 0.15

--// ============================================ //
--//              UI CONSTRUCTION                 //
--// ============================================ //

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoParryHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = game:GetService("CoreGui")

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 320, 0, 420)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Draggable = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(40, 40, 40)
MainStroke.Thickness = 1

-- Header (Draggable Area)
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner", Header)
HeaderCorner.CornerRadius = UDim.new(0, 12)

-- Fix bottom corners of header
local HeaderFix = Instance.new("Frame")
HeaderFix.Size = UDim2.new(1, 0, 0, 12)
HeaderFix.Position = UDim2.new(0, 0, 1, -12)
HeaderFix.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
HeaderFix.BorderSizePixel = 0
HeaderFix.Parent = Header

local TitleLabel = Instance.new("TextLabel")
TitleLabel.BackgroundTransparency = 1
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.Text = "Auto Parry"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

-- Status Indicator
local StatusLabel = Instance.new("TextLabel")
StatusLabel.Name = "StatusIndicator"
StatusLabel.BackgroundTransparency = 1
StatusLabel.Size = UDim2.new(0, 100, 0, 20)
StatusLabel.Position = UDim2.new(1, -110, 0.5, -10)
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.Text = "● Aguardando Args"
StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Right
StatusLabel.Parent = Header

-- Content Container
local Content = Instance.new("ScrollingFrame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -20, 1, -50)
Content.Position = UDim2.new(0, 10, 0, 45)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.CanvasSize = UDim2.new(0, 0, 0, 600)
Content.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout", Content)
ListLayout.Padding = UDim.new(0, 12)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder

--// UI HELPER FUNCTIONS //

local function createSection(title)
    local section = Instance.new("Frame")
    section.Name = "Section_" .. title
    section.Size = UDim2.new(1, 0, 0, 30)
    section.BackgroundTransparency = 1
    section.Parent = Content
    
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 1, 0)
    label.Font = Enum.Font.GothamSemibold
    label.Text = title
    label.TextColor3 = Color3.fromRGB(180, 180, 180)
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = section
    
    return section
end

local function createToggle(name, default, callback)
    local container = Instance.new("Frame")
    container.Name = "Toggle_" .. name
    container.Size = UDim2.new(1, 0, 0, 36)
    container.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    container.BorderSizePixel = 0
    container.Parent = Content
    
    local corner = Instance.new("UICorner", container)
    corner.CornerRadius = UDim.new(0, 8)
    
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -60, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local toggleBg = Instance.new("Frame")
    toggleBg.Name = "ToggleBg"
    toggleBg.Size = UDim2.new(0, 40, 0, 22)
    toggleBg.Position = UDim2.new(1, -52, 0.5, -11)
    toggleBg.BackgroundColor3 = default and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 60)
    toggleBg.BorderSizePixel = 0
    toggleBg.Parent = container
    
    local toggleCorner = Instance.new("UICorner", toggleBg)
    toggleCorner.CornerRadius = UDim.new(1, 0)
    
    local toggleKnob = Instance.new("Frame")
    toggleKnob.Name = "ToggleKnob"
    toggleKnob.Size = UDim2.new(0, 18, 0, 18)
    toggleKnob.Position = default and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
    toggleKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    toggleKnob.BorderSizePixel = 0
    toggleKnob.Parent = toggleBg
    
    local knobCorner = Instance.new("UICorner", toggleKnob)
    knobCorner.CornerRadius = UDim.new(1, 0)
    
    local state = default
    container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            state = not state
            local targetColor = state and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 60)
            local targetPos = state and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)
            
            TweenService:Create(toggleBg, TweenInfo.new(0.2), {BackgroundColor3 = targetColor}):Play()
            TweenService:Create(toggleKnob, TweenInfo.new(0.2), {Position = targetPos}):Play()
            
            if callback then callback(state) end
        end
    end)
    
    return container
end

local function createSlider(name, min, max, default, callback)
    local container = Instance.new("Frame")
    container.Name = "Slider_" .. name
    container.Size = UDim2.new(1, 0, 0, 50)
    container.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    container.BorderSizePixel = 0
    container.Parent = Content
    
    local corner = Instance.new("UICorner", container)
    corner.CornerRadius = UDim.new(0, 8)
    
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.6, 0, 0, 20)
    label.Position = UDim2.new(0, 12, 0, 8)
    label.Font = Enum.Font.GothamMedium
    label.Text = name
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Name = "ValueLabel"
    valueLabel.BackgroundTransparency = 1
    valueLabel.Size = UDim2.new(0.4, -12, 0, 20)
    valueLabel.Position = UDim2.new(0.6, 0, 0, 8)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Color3.fromRGB(80, 200, 120)
    valueLabel.TextSize = 13
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = container
    
    local sliderBg = Instance.new("Frame")
    sliderBg.Name = "SliderBg"
    sliderBg.Size = UDim2.new(1, -24, 0, 6)
    sliderBg.Position = UDim2.new(0, 12, 0, 34)
    sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = container
    
    local sliderCorner = Instance.new("UICorner", sliderBg)
    sliderCorner.CornerRadius = UDim.new(1, 0)
    
    local sliderFill = Instance.new("Frame")
    sliderFill.Name = "SliderFill"
    local pct = (default - min) / (max - min)
    sliderFill.Size = UDim2.new(pct, 0, 1, 0)
    sliderFill.BackgroundColor3 = Color3.fromRGB(80, 200, 120)
    sliderFill.BorderSizePixel = 0
    sliderFill.Parent = sliderBg
    
    local fillCorner = Instance.new("UICorner", sliderFill)
    fillCorner.CornerRadius = UDim.new(1, 0)
    
    local dragging = false
    local function update(input)
        local pos = math.clamp((input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
        local val = math.floor(min + (max - min) * pos)
        sliderFill.Size = UDim2.new(pos, 0, 1, 0)
        valueLabel.Text = tostring(val)
        if callback then callback(val) end
    end
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    return container
end

local function createDropdown(name, options, default, callback)
    local container = Instance.new("Frame")
    container.Name = "Dropdown_" .. name
    container.Size = UDim2.new(1, 0, 0, 36)
    container.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    container.BorderSizePixel = 0
    container.Parent = Content
    
    local corner = Instance.new("UICorner", container)
    corner.CornerRadius = UDim.new(0, 8)
    
    local selected = default or options[1]
    
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -40, 1, 0)
    label.Position = UDim2.new(0, 12, 0, 0)
    label.Font = Enum.Font.GothamMedium
    label.Text = name .. ": " .. selected
    label.TextColor3 = Color3.fromRGB(220, 220, 220)
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = container
    
    local arrow = Instance.new("TextLabel")
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.new(0, 20, 1, 0)
    arrow.Position = UDim2.new(1, -30, 0, 0)
    arrow.Font = Enum.Font.GothamBold
    arrow.Text = "▼"
    arrow.TextColor3 = Color3.fromRGB(150, 150, 150)
    arrow.TextSize = 10
    arrow.Parent = container
    
    local listContainer = Instance.new("Frame")
    listContainer.Name = "DropdownList"
    listContainer.Size = UDim2.new(1, 0, 0, 0)
    listContainer.Position = UDim2.new(0, 0, 1, 4)
    listContainer.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    listContainer.BorderSizePixel = 0
    listContainer.Visible = false
    listContainer.ClipsDescendants = true
    listContainer.Parent = container
    
    local listCorner = Instance.new("UICorner", listContainer)
    listCorner.CornerRadius = UDim.new(0, 8)
    
    local listLayout = Instance.new("UIListLayout", listContainer)
    listLayout.Padding = UDim.new(0, 2)
    
    for _, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Name = "Opt_" .. opt
        optBtn.Size = UDim2.new(1, 0, 0, 28)
        optBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        optBtn.BorderSizePixel = 0
        optBtn.Font = Enum.Font.GothamMedium
        optBtn.Text = opt
        optBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
        optBtn.TextSize = 12
        optBtn.Parent = listContainer
        
        local optCorner = Instance.new("UICorner", optBtn)
        optCorner.CornerRadius = UDim.new(0, 6)
        
        optBtn.MouseButton1Click:Connect(function()
            selected = opt
            label.Text = name .. ": " .. opt
            listContainer.Visible = false
            listContainer.Size = UDim2.new(1, 0, 0, 0)
            if callback then callback(opt) end
        end)
    end
    
    local isOpen = false
    container.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            isOpen = not isOpen
            if isOpen then
                listContainer.Visible = true
                TweenService:Create(listContainer, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, #options * 30)}):Play()
            else
                TweenService:Create(listContainer, TweenInfo.new(0.2), {Size = UDim2.new(1, 0, 0, 0)}):Play()
                task.wait(0.2)
                listContainer.Visible = false
            end
        end
    end)
    
    return container
end

--// BUILD UI //

createSection("COMBAT")

createToggle("Auto Parry", Config.Enabled, function(state)
    Config.Enabled = state
    if state and not CachedArgs then
        warn("[PHANTOM] ⚠️ DÊ UM PARRY MANUAL AGORA PARA CAPTURAR ARGUMENTOS!")
    end
end)

createSlider("Accuracy", 0, 100, Config.Accuracy, function(val)
    Config.Accuracy = val
end)

createToggle("Randomize Accuracy", Config.RandomizeAccuracy, function(state)
    Config.RandomizeAccuracy = state
end)

createSlider("Random Range Min", 0, 100, Config.RandomRange[1], function(val)
    Config.RandomRange[1] = val
end)

createSlider("Random Range Max", 0, 100, Config.RandomRange[2], function(val)
    Config.RandomRange[2] = val
end)

createDropdown("Parry Mode", {"Remote", "Mouse"}, Config.ParryMode, function(opt)
    Config.ParryMode = opt
end)

createSection("STATUS")

--// DRAG LOGIC //
local dragging = false
local dragStart = nil
local startPos = nil

Header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

--// ============================================ //
--//           BYPASS & ARG SNIFFER               //
--// ============================================ //

local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if self == Remotes:FindFirstChild("ParryAttempt") and method == "FireServer" then
        CachedArgs = args
        StatusLabel.Text = "● Args Capturados"
        StatusLabel.TextColor3 = Color3.fromRGB(80, 200, 120)
    end
    
    return OldNamecall(self, ...)
end)

--// ============================================ //
--//             CORE LOGIC                       //
--// ============================================ //

local function getTargetBall()
    for _, ball in ipairs(BallFolder:GetChildren()) do
        if ball:GetAttribute("realBall") or ball:FindFirstChild("zoomies") then
            local vel = ball.AssemblyLinearVelocity
            if vel and vel.Magnitude > 10 then
                return ball, vel.Magnitude
            end
        end
    end
    return nil, 0
end

local function shouldParry()
    if not Config.Enabled then return false end
    
    local acc = Config.Accuracy
    if Config.RandomizeAccuracy then
        acc = math.random(Config.RandomRange[1], Config.RandomRange[2])
    end
    
    return math.random(1, 100) <= acc
end

local function executeParry()
    local now = tick()
    if now - LastParryTime < CooldownProtection then return end
    
    if not shouldParry() then return end
    
    LastParryTime = now
    
    if Config.ParryMode == "Remote" then
        if CachedArgs then
            pcall(function()
                Remotes.ParryAttempt:FireServer(unpack(CachedArgs))
            end)
        else
            pcall(function()
                Remotes.ParryButtonPress:Fire()
            end)
        end
    elseif Config.ParryMode == "Mouse" then
        pcall(function()
            Remotes.ParryButtonPress:Fire()
        end)
    end
end

RunService.RenderStepped:Connect(function(dt)
    if not Config.Enabled then return end
    
    local ball, speed = getTargetBall()
    if not ball then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local dist = (ball.Position - hrp.Position).Magnitude
    local threshold = Config.MinDistance + (speed * Config.PredictionOffset)
    
    if dist <= threshold then
        executeParry()
    end
end)

--// INSTRUCTIONS //
print("========================================")
print("  PHANTOM AUTO PARRY HUB v1099")
print("========================================")
print("  [!] DÊ UM PARRY MANUAL PARA CAPTURAR ARGS")
print("  [!] MODO REMOTE USA ARGS CACHEADOS")
print("  [!] MODO MOUSE USA BINDABLE INTERNO")
print("  [!] AJUSTE ACCURACY PARA EVITAR DETECÇÃO")
print("========================================")
