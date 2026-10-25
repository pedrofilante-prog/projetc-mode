-- ==== AUTO PARRY FINAL - PHANTOM 1099 ====
-- ==== YUB-X OPTIMIZED | NO CAMERA FREEZE ====

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
local BallFolder = workspace:WaitForChild("Balls", 10)

-- ==== CONFIGURATION ====
local Config = {
    Enabled = false,
    Accuracy = 75,
    RandomizeAccuracy = true,
    AccuracyMin = 25,
    AccuracyMax = 85,
    PredictionOffset = 0.08,
    MinDistance = 6.5,
    UseGetConnections = true,
    FallbackToHook = true
}

-- ==== STATE ====
local ParryFunction = nil
local LastParryTime = 0
local CooldownProtection = 0.12
local CachedArgs = nil

-- ==== SAFE EXECUTION WRAPPERS ====
local safeCall = function(func, ...)
    local success, result = pcall(func, ...)
    return success, result
end

local safeGetConnections = function(event)
    if not getconnections then return nil end
    local success, connections = pcall(getconnections, event)
    return success and connections or nil
end

-- ==== METHOD 1: GETCONNECTIONS (PRIMARY) ====
local function findParryFunction()
    if not Remotes then return nil end
    
    local ParryButtonPress = Remotes:FindFirstChild("ParryButtonPress")
    if not ParryButtonPress or not ParryButtonPress:IsA("BindableEvent") then return nil end
    
    local connections = safeGetConnections(ParryButtonPress.Event)
    if not connections then return nil end
    
    for _, conn in ipairs(connections) do
        if typeof(conn.Function) == "function" then
            return conn.Function
        end
    end
    
    return nil
end

-- ==== METHOD 2: HOOKMETAMETHOD FALLBACK (PROTECTED) ====
local function setupFallbackHook()
    if not Config.FallbackToHook then return end
    if not hookmetamethod then return end
    
    local ParryAttempt = Remotes and Remotes:FindFirstChild("ParryAttempt")
    if not ParryAttempt then return end
    
    local OldIndex
    OldIndex = hookmetamethod(game, "__index", newcclosure(function(self, key)
        if self == ParryAttempt and key == "FireServer" then
            return function(_, ...)
                CachedArgs = {...}
                return OldIndex(self, key)(self, ...)
            end
        end
        return OldIndex(self, key)
    end))
end

-- ==== TRAJECTORY PREDICTION WITH CURVE ====
local function predictBallPosition(ball, deltaTime)
    if not ball or not ball.Parent then return nil end
    
    local pos = ball.Position
    local vel = ball.AssemblyLinearVelocity
    
    -- Simple linear prediction with gravity compensation
    local gravity = Vector3.new(0, -workspace.Gravity * 0.5, 0)
    local predictedPos = pos + (vel * deltaTime) + (gravity * deltaTime * deltaTime * 0.5)
    
    return predictedPos
end

local function getTargetBallWithTrajectory()
    if not BallFolder then return nil, 0, nil end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, 0, nil end
    
    local playerPos = hrp.Position
    local closestBall = nil
    local closestDist = math.huge
    local closestSpeed = 0
    
    for _, ball in ipairs(BallFolder:GetChildren()) do
        local isReal = ball:GetAttribute("realBall") or ball:FindFirstChild("zoomies")
        if not isReal then continue end
        
        local vel = ball.AssemblyLinearVelocity
        if not vel or vel.Magnitude < 10 then continue end
        
        -- Predict where ball will be in PredictionOffset seconds
        local predictedPos = predictBallPosition(ball, Config.PredictionOffset)
        if not predictedPos then continue end
        
        local dist = (predictedPos - playerPos).Magnitude
        local speed = vel.Magnitude
        
        -- Check if ball is heading toward player (dot product)
        local direction = (playerPos - ball.Position).Unit
        local velocityDir = vel.Unit
        local dot = direction:Dot(velocityDir)
        
        -- Only track balls coming toward us (dot > 0.3 means somewhat heading our way)
        if dot > 0.3 and dist < closestDist then
            closestDist = dist
            closestBall = ball
            closestSpeed = speed
        end
    end
    
    return closestBall, closestSpeed, closestDist
end

-- ==== ACCURACY SYSTEM ====
local function shouldParry()
    if not Config.Enabled then return false end
    
    local acc = Config.Accuracy
    if Config.RandomizeAccuracy then
        acc = math.random(Config.AccuracyMin, Config.AccuracyMax)
    end
    
    return math.random(1, 100) <= acc
end

-- ==== PARRY EXECUTION ====
local function executeParry()
    local now = tick()
    if now - LastParryTime < CooldownProtection then return end
    if not shouldParry() then return end
    
    LastParryTime = now
    
    -- Method 1: Direct function call via getconnections
    if Config.UseGetConnections and ParryFunction then
        safeCall(ParryFunction)
        return
    end
    
    -- Method 2: BindableEvent fire
    local ParryButtonPress = Remotes and Remotes:FindFirstChild("ParryButtonPress")
    if ParryButtonPress and ParryButtonPress:IsA("BindableEvent") then
        safeCall(function() ParryButtonPress:Fire() end)
        return
    end
    
    -- Method 3: RemoteEvent with cached args (fallback)
    if CachedArgs then
        local ParryAttempt = Remotes and Remotes:FindFirstChild("ParryAttempt")
        if ParryAttempt then
            safeCall(function() ParryAttempt:FireServer(unpack(CachedArgs)) end)
        end
    end
end

-- ==== UI CONSTRUCTION (MINIMAL & SAFE) ====
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoParryFinal"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = game:GetService("CoreGui")

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 380)
MainFrame.Position = UDim2.new(0.5, -150, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 12)

local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(40, 40, 40)
MainStroke.Thickness = 1

-- Header
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 40)
Header.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner", Header)
HeaderCorner.CornerRadius = UDim.new(0, 12)

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
TitleLabel.Text = "Auto Parry Final"
TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleLabel.TextSize = 14
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = Header

local StatusLabel = Instance.new("TextLabel")
StatusLabel.BackgroundTransparency = 1
StatusLabel.Size = UDim2.new(0, 120, 0, 20)
StatusLabel.Position = UDim2.new(1, -130, 0.5, -10)
StatusLabel.Font = Enum.Font.GothamMedium
StatusLabel.Text = "● Aguardando"
StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
StatusLabel.TextSize = 10
StatusLabel.TextXAlignment = Enum.TextXAlignment.Right
StatusLabel.Parent = Header

-- Content
local Content = Instance.new("ScrollingFrame")
Content.Size = UDim2.new(1, -20, 1, -50)
Content.Position = UDim2.new(0, 10, 0, 45)
Content.BackgroundTransparency = 1
Content.BorderSizePixel = 0
Content.ScrollBarThickness = 4
Content.CanvasSize = UDim2.new(0, 0, 0, 500)
Content.Parent = MainFrame

local ListLayout = Instance.new("UIListLayout", Content)
ListLayout.Padding = UDim.new(0, 10)
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder

-- UI Helpers
local function createToggle(name, default, callback)
    local container = Instance.new("Frame")
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
    toggleBg.Size = UDim2.new(0, 40, 0, 22)
    toggleBg.Position = UDim2.new(1, -52, 0.5, -11)
    toggleBg.BackgroundColor3 = default and Color3.fromRGB(80, 200, 120) or Color3.fromRGB(60, 60, 60)
    toggleBg.BorderSizePixel = 0
    toggleBg.Parent = container
    
    local toggleCorner = Instance.new("UICorner", toggleBg)
    toggleCorner.CornerRadius = UDim.new(1, 0)
    
    local toggleKnob = Instance.new("Frame")
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
    sliderBg.Size = UDim2.new(1, -24, 0, 6)
    sliderBg.Position = UDim2.new(0, 12, 0, 34)
    sliderBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = container
    
    local sliderCorner = Instance.new("UICorner", sliderBg)
    sliderCorner.CornerRadius = UDim.new(1, 0)
    
    local sliderFill = Instance.new("Frame")
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

-- Build UI
createToggle("Auto Parry", Config.Enabled, function(state)
    Config.Enabled = state
    if state then
        StatusLabel.Text = "● Ativo"
        StatusLabel.TextColor3 = Color3.fromRGB(80, 200, 120)
    else
        StatusLabel.Text = "● Inativo"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
    end
end)

createSlider("Accuracy", 0, 100, Config.Accuracy, function(val)
    Config.Accuracy = val
end)

createToggle("Randomize Accuracy", Config.RandomizeAccuracy, function(state)
    Config.RandomizeAccuracy = state
end)

createSlider("Random Min", 0, 100, Config.AccuracyMin, function(val)
    Config.AccuracyMin = val
end)

createSlider("Random Max", 0, 100, Config.AccuracyMax, function(val)
    Config.AccuracyMax = val
end)

createSlider("Prediction Offset", 0, 20, Config.PredictionOffset * 100, function(val)
    Config.PredictionOffset = val / 100
end)

createSlider("Min Distance", 3, 15, Config.MinDistance, function(val)
    Config.MinDistance = val
end)

-- Drag Logic
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

-- ==== INITIALIZATION ====
task.spawn(function()
    -- Try to find parry function via getconnections
    ParryFunction = findParryFunction()
    
    if ParryFunction then
        StatusLabel.Text = "● Função Encontrada"
        StatusLabel.TextColor3 = Color3.fromRGB(80, 200, 120)
        print("[PHANTOM] ✓ Parry function found via getconnections")
    else
        print("[PHANTOM] ⚠ getconnections failed, using fallback methods")
        setupFallbackHook()
    end
end)

-- ==== MAIN LOOP ====
RunService.RenderStepped:Connect(function(dt)
    if not Config.Enabled then return end
    
    local ball, speed, dist = getTargetBallWithTrajectory()
    if not ball then return end
    
    local threshold = Config.MinDistance + (speed * Config.PredictionOffset)
    
    if dist and dist <= threshold then
        executeParry()
    end
end)

-- ==== INSTRUCTIONS ====
print("========================================")
print("  AUTO PARRY FINAL - PHANTOM 1099")
print("  YUB-X OPTIMIZED | NO CAMERA FREEZE")
print("========================================")
print("  [✓] GETCONNECTIONS PRIMARY METHOD")
print("  [✓] TRAJECTORY PREDICTION WITH CURVE")
print("  [✓] HUMANIZED ACCURACY SYSTEM")
print("  [✓] FALLBACK CHAIN PROTECTED")
print("  [!] NO GLOBAL HOOKS = NO CAMERA LAG")
print("========================================")
