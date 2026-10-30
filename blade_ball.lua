-- ==== TRIGGERBOT v4 - PHANTOM 1099 ====
-- ==== REACAO PURA | BANDA DE LATENCIA | BURST FIRE ====

local cloneref = cloneref or function(obj) return obj end
local gethui = gethui or function() return nil end

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local Stats = cloneref(game:GetService("Stats"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Workspace = cloneref(game:GetService("Workspace"))

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local CONFIG = {
    ParryRange = 14,     -- alcance da espada no server. - e + ajustam
    PingComp = 1.0,      -- multiplicador do lead. [ e ] ajustam
    BurstCount = 3,      -- cliques por rajada
    BurstGap = 0.07,     -- intervalo entre cliques da rajada
    Lockout = 0.42,      -- pausa apos rajada
    KillGuard = 5,       -- bola ja colou = clique de panico
    PromoteDot = 0.60,   -- promocao de alvo por trajetoria
    SpamInterval = 0.14,
}

local Settings = {
    Trigger = false,
    AutoSpam = false,
    ShowAura = false,
}

local State = {
    Attempts = 0,
    Confirms = 0,
    LastBurstStart = -10,
    BurstToken = 0,
    PingCache = 0.06,
    PingTimer = 0,
    MainConnection = nil,
    ScreenGui = nil,
    MainFrame = nil,
    Indicator = nil,
    AuraDrawing = nil,
    LastDispatch = "init",
    LastBand = "--",
    LastDist = 0,
    LastCS = 0,
}

-- ==== CONFIRMACAO ====
pcall(function()
    local Remotes = game:GetService("ReplicatedStorage"):WaitForChild("Remotes", 10)
    local ps = Remotes:FindFirstChild("ParrySuccess")
    if ps and ps:IsA("RemoteEvent") then
        ps.OnClientEvent:Connect(function() State.Confirms = State.Confirms + 1 end)
    end
    local psc = Remotes:FindFirstChild("ParrySuccessClient")
    if psc and psc:IsA("BindableEvent") then
        psc.Event:Connect(function() State.Confirms = State.Confirms + 1 end)
    end
end)

-- ==== PING CACHEADO (nao chama Stats todo frame) ====
local function UpdatePing(now)
    if now - State.PingTimer < 0.3 then return end
    State.PingTimer = now
    pcall(function()
        State.PingCache = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
end

-- ==== DISPATCH (MOUSE PRIMEIRO, PROVADO NO YUB-X) ====
local function SendParryInput()
    if mouse1click then
        pcall(mouse1click)
        State.LastDispatch = "m1click"
        return true
    end
    if mouse1press then
        pcall(mouse1press)
        if mouse1release then task.defer(mouse1release) end
        State.LastDispatch = "m1press"
        return true
    end
    local ok, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if ok and vim then
        pcall(function() vim:SendMouseButtonEvent(0, 0, 0, true, game, 0) end)
        task.defer(function()
            pcall(function() vim:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
        end)
        State.LastDispatch = "vim"
        return true
    end
    State.LastDispatch = "SEM_METODO"
    return false
end

-- ==== BURST FIRE ====
local function FireBurst()
    State.LastBurstStart = os.clock()
    State.Attempts = State.Attempts + 1
    State.BurstToken = State.BurstToken + 1
    local token = State.BurstToken
    task.spawn(function()
        for i = 1, CONFIG.BurstCount do
            if State.BurstToken ~= token then break end
            SendParryInput()
            if i < CONFIG.BurstCount then task.wait(CONFIG.BurstGap) end
        end
    end)
end

-- ==== DETECCAO ENXUTA ====
local function ResolveBasePart(inst)
    if inst:IsA("BasePart") then return inst end
    if inst:IsA("Model") then
        if inst.PrimaryPart then return inst.PrimaryPart end
        for _, child in ipairs(inst:GetChildren()) do
            if child:IsA("BasePart") then return child end
        end
    end
    return nil
end

local function IsCharacter(inst)
    if inst:FindFirstChildOfClass("Humanoid") then return true end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character == inst then return true end
    end
    return false
end

local function GetTargetAttr(ball)
    for _, attr in ipairs({"target", "Target", "TargetPlayer"}) do
        local val = ball:GetAttribute(attr)
        if val == nil and ball.Parent then val = ball.Parent:GetAttribute(attr) end
        if val ~= nil and val ~= "" then return val end
    end
    return nil
end

local function IsTargetMe(ball)
    local val = GetTargetAttr(ball)
    if val == nil then return nil end
    if typeof(val) == "Instance" then
        if val == LocalPlayer or val == LocalPlayer.Character then return true end
        if LocalPlayer.Character and val:IsDescendantOf(LocalPlayer.Character) then return true end
        return false
    end
    local s = tostring(val)
    if s == LocalPlayer.Name or s == LocalPlayer.DisplayName or s == tostring(LocalPlayer.UserId) then
        return true
    end
    return false
end

local function GetThreatBall(root)
    local candidates, seen = {}, {}
    local folders = {
        Workspace:FindFirstChild("Balls"),
        Workspace:FindFirstChild("TrainingBalls"),
        Workspace:FindFirstChild("Training"),
    }
    for _, folder in ipairs(folders) do
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                if not IsCharacter(child) then
                    local part = ResolveBasePart(child)
                    if part and not seen[part] then
                        seen[part] = true
                        table.insert(candidates, part)
                    end
                end
            end
        end
    end
    if #candidates == 0 then return nil, false end

    -- 1: alvo confirmado por atributo
    for _, ball in ipairs(candidates) do
        if IsTargetMe(ball) == true then return ball, true end
    end

    -- 2: trajetoria apontando pra mim (triggerbot promove rapido)
    local bestBall, bestScore = nil, -1
    for _, ball in ipairs(candidates) do
        local vel = ball.AssemblyLinearVelocity
        local spd = vel.Magnitude
        if spd > 15 then
            local toMe = root.Position - ball.Position
            local dist = toMe.Magnitude
            if dist < 70 then
                local dot = vel.Unit:Dot(toMe.Unit)
                if dot > CONFIG.PromoteDot then
                    local score = dot * spd / math.max(dist, 1)
                    if score > bestScore then
                        bestScore = score
                        bestBall = ball
                    end
                end
            end
        end
    end
    if bestBall then return bestBall, true end

    -- 3: mais proxima (fallback)
    local closest, closestDist = nil, math.huge
    for _, ball in ipairs(candidates) do
        local dist = (ball.Position - root.Position).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = ball
        end
    end
    return closest, false
end

-- ==== UI ====
local function CreateUI()
    local secureParent = gethui()
    if not secureParent then
        local ok, core = pcall(function() return cloneref(game:GetService("CoreGui")) end)
        secureParent = (ok and core) or LocalPlayer:WaitForChild("PlayerGui")
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "phantomv4"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    if syn and syn.protect_gui then pcall(syn.protect_gui, ScreenGui) end
    ScreenGui.Parent = secureParent
    State.ScreenGui = ScreenGui

    local indicator = Instance.new("TextLabel")
    indicator.AnchorPoint = Vector2.new(1, 1)
    indicator.Position = UDim2.new(1, -8, 1, -8)
    indicator.Size = UDim2.new(0, 235, 0, 46)
    indicator.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    indicator.BackgroundTransparency = 0.35
    indicator.BorderSizePixel = 0
    indicator.Font = Enum.Font.Code
    indicator.TextSize = 10
    indicator.TextColor3 = Color3.fromRGB(160, 210, 160)
    indicator.TextXAlignment = Enum.TextXAlignment.Left
    indicator.TextWrapped = true
    indicator.Active = false
    indicator.Text = "TRIG v4 | OFF | R14 C1.0\nAGUARDANDO BOLA..."
    indicator.Parent = ScreenGui
    State.Indicator = indicator
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 4)

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 240, 0, 250)
    MainFrame.Position = UDim2.new(0.04, 0, 0.30, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui
    State.MainFrame = MainFrame
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", MainFrame).Color = Color3.fromRGB(40, 40, 52)

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 30)
    TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 6)

    local TitleText = Instance.new("TextLabel")
    TitleText.Size = UDim2.new(1, -10, 1, 0)
    TitleText.Position = UDim2.new(0, 10, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "TRIGGERBOT v4 | P = menu"
    TitleText.TextColor3 = Color3.fromRGB(215, 215, 225)
    TitleText.TextSize = 10
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    TitleText.Parent = TitleBar

    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, -16, 1, -38)
    Container.Position = UDim2.new(0, 8, 0, 34)
    Container.BackgroundTransparency = 1
    Container.Parent = MainFrame
    local layout = Instance.new("UIListLayout", Container)
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local function SetUIVisible(v)
        MainFrame.Visible = v
        MainFrame.Active = v
    end

    local function CreateButton(order, text, defaultState, callback)
        local btn = Instance.new("TextButton")
        btn.LayoutOrder = order
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = defaultState and Color3.fromRGB(30, 65, 40) or Color3.fromRGB(25, 25, 32)
        btn.BorderSizePixel = 0
        btn.Font = Enum.Font.GothamSemibold
        btn.TextSize = 11
        btn.TextColor3 = Color3.fromRGB(230, 230, 235)
        btn.Text = string.format("%s: %s", text, defaultState and "[ON]" or "[OFF]")
        btn.AutoButtonColor = false
        btn.Parent = Container
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        local active = defaultState
        btn.MouseButton1Click:Connect(function()
            active = not active
            btn.BackgroundColor3 = active and Color3.fromRGB(30, 65, 40) or Color3.fromRGB(25, 25, 32)
            btn.Text = string.format("%s: %s", text, active and "[ON]" or "[OFF]")
            callback(active)
        end)
    end

    CreateButton(1, "TriggerBot", false, function(v)
        Settings.Trigger = v
        if v then SetUIVisible(false) end
    end)
    CreateButton(2, "Auto Spam", false, function(v) Settings.AutoSpam = v end)
    CreateButton(3, "Visual Aura", false, function(v) Settings.ShowAura = v end)

    local infoLabel = Instance.new("TextLabel")
    infoLabel.LayoutOrder = 4
    infoLabel.Size = UDim2.new(1, 0, 0, 36)
    infoLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    infoLabel.BorderSizePixel = 0
    infoLabel.Font = Enum.Font.Code
    infoLabel.TextSize = 10
    infoLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
    infoLabel.TextWrapped = true
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Text = "RANGE 14 (- e +)\nCOMP 1.0 ([ e ])"
    infoLabel.Parent = Container
    Instance.new("UICorner", infoLabel).CornerRadius = UDim.new(0, 4)

    local killBtn = Instance.new("TextButton")
    killBtn.LayoutOrder = 9
    killBtn.Size = UDim2.new(1, 0, 0, 30)
    killBtn.BackgroundColor3 = Color3.fromRGB(55, 20, 20)
    killBtn.BorderSizePixel = 0
    killBtn.Font = Enum.Font.GothamBold
    killBtn.TextSize = 11
    killBtn.TextColor3 = Color3.fromRGB(255, 110, 110)
    killBtn.Text = "FINALIZAR [KILL]"
    killBtn.AutoButtonColor = false
    killBtn.Parent = Container
    Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 4)
    killBtn.MouseButton1Click:Connect(function()
        if State.MainConnection then State.MainConnection:Disconnect() State.MainConnection = nil end
        State.BurstToken = State.BurstToken + 1
        if State.AuraDrawing then pcall(function() State.AuraDrawing:Remove() end) State.AuraDrawing = nil end
        if State.ScreenGui then State.ScreenGui:Destroy() State.ScreenGui = nil end
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.P then
            SetUIVisible(not MainFrame.Visible)
        elseif input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.KeypadMinus then
            CONFIG.ParryRange = math.clamp(CONFIG.ParryRange - 1, 6, 30)
            infoLabel.Text = string.format("RANGE %d (- e +)\nCOMP %.1f ([ e ])", CONFIG.ParryRange, CONFIG.PingComp)
        elseif input.KeyCode == Enum.KeyCode.Equal or input.KeyCode == Enum.KeyCode.KeypadPlus then
            CONFIG.ParryRange = math.clamp(CONFIG.ParryRange + 1, 6, 30)
            infoLabel.Text = string.format("RANGE %d (- e +)\nCOMP %.1f ([ e ])", CONFIG.ParryRange, CONFIG.PingComp)
        elseif input.KeyCode == Enum.KeyCode.LeftBracket then
            CONFIG.PingComp = math.clamp(CONFIG.PingComp - 0.1, 0.4, 2.0)
            infoLabel.Text = string.format("RANGE %d (- e +)\nCOMP %.1f ([ e ])", CONFIG.ParryRange, CONFIG.PingComp)
        elseif input.KeyCode == Enum.KeyCode.RightBracket then
            CONFIG.PingComp = math.clamp(CONFIG.PingComp + 0.1, 0.4, 2.0)
            infoLabel.Text = string.format("RANGE %d (- e +)\nCOMP %.1f ([ e ])", CONFIG.ParryRange, CONFIG.PingComp)
        end
    end)
end

CreateUI()

pcall(function()
    if Drawing and Drawing.new then
        local circle = Drawing.new("Circle")
        circle.Thickness = 2
        circle.NumSides = 48
        circle.Filled = false
        circle.Transparency = 0.7
        circle.Color = Color3.fromRGB(50, 255, 120)
        circle.Visible = false
        State.AuraDrawing = circle
    end
end)

-- ==== LOOP TRIGGERBOT ====
local renderEvent = RunService.PreRender or RunService.RenderStepped
local lastSpam = 0

State.MainConnection = renderEvent:Connect(function()
    local now = os.clock()
    UpdatePing(now)

    if Settings.AutoSpam and (now - lastSpam) >= CONFIG.SpamInterval then
        lastSpam = now
        SendParryInput()
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local ball, isTarget = GetThreatBall(root)

    if not ball then
        if State.Indicator then
            State.Indicator.Text = string.format("TRIG v4 | %s | R%d C%.1f | PING %dms\nSEM BOLA | ATT %d | CONF %d",
                Settings.Trigger and "ON" or "OFF", CONFIG.ParryRange, CONFIG.PingComp,
                math.floor(State.PingCache * 1000), State.Attempts, State.Confirms)
        end
        return
    end

    local dist = (ball.Position - root.Position).Magnitude
    local vel = ball.AssemblyLinearVelocity
    local speed = vel.Magnitude
    local closing = 0
    if speed > 1 then
        closing = vel.Unit:Dot((root.Position - ball.Position).Unit) * speed
    end

    -- BANDA DE LATENCIA: o coracao do triggerbot
    local lead = speed * State.PingCache * CONFIG.PingComp
    local bandHigh = CONFIG.ParryRange + lead
    local bandLow = CONFIG.KillGuard + lead * 0.4
    State.LastBand = string.format("%.0f-%.0f", bandLow, bandHigh)
    State.LastDist = dist
    State.LastCS = closing

    local inBand = dist <= bandHigh and closing > 0
    local panic = dist <= CONFIG.KillGuard + 4 and closing > 15

    if Settings.Trigger and isTarget and (inBand or panic) then
        if (now - State.LastBurstStart) >= CONFIG.Lockout then
            FireBurst()
        end
    end

    -- aura desenha a banda real
    if State.AuraDrawing then
        if Settings.ShowAura then
            local sp, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen and sp.Z > 0 then
                local edge = Camera:WorldToViewportPoint(root.Position + Camera.CFrame.RightVector * bandHigh)
                State.AuraDrawing.Position = Vector2.new(sp.X, sp.Y)
                State.AuraDrawing.Radius = math.clamp((Vector2.new(sp.X, sp.Y) - Vector2.new(edge.X, edge.Y)).Magnitude, 15, 900)
                State.AuraDrawing.Color = inBand and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(50, 255, 120)
                State.AuraDrawing.Visible = true
            else
                State.AuraDrawing.Visible = false
            end
        else
            State.AuraDrawing.Visible = false
        end
    end

    if State.Indicator then
        local rate = State.Attempts > 0 and math.floor((State.Confirms / State.Attempts) * 100) or 0
        State.Indicator.Text = string.format(
            "TRIG v4 | %s | R%d C%.1f | PING %dms\nDIST %.1f | BANDA [%s] | CS %.0f\nATT %d | CONF %d | TAXA %d%%",
            Settings.Trigger and "ON" or "OFF", CONFIG.ParryRange, CONFIG.PingComp,
            math.floor(State.PingCache * 1000),
            dist, State.LastBand, closing,
            State.Attempts, State.Confirms, rate
        )
        State.Indicator.TextColor3 = inBand and Color3.fromRGB(255, 120, 120)
            or (Settings.Trigger and Color3.fromRGB(120, 240, 140) or Color3.fromRGB(200, 120, 120))
    end
end)

print("========================================")
print("  TRIGGERBOT v4 - PHANTOM 1099")
print("  BANDA DE LATENCIA | BURST FIRE")
print("========================================")
print("  P       = mostrar/ocultar menu")
print("  - / +   = range da espada")
print("  [ / ]   = compensacao de ping")
print("----------------------------------------")
print("  Morre com a bola colando?  sobe COMP (])")
print("  Swing no vacuo?            desce COMP ([)")
print("  Comece: RANGE 14, COMP 1.0")
print("  TAXA = CONFIRM / RAJADAS (nao por clique)")
print("========================================")
