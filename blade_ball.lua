-- ==== AUTO PARRY v3 - PHANTOM 1099 ====
-- ==== RANGE LOCK | UI CLICK-SAFE | YUB-X ====

local cloneref = cloneref or function(obj) return obj end
local gethui = gethui or function() return nil end

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local Stats = cloneref(game:GetService("Stats"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Workspace = cloneref(game:GetService("Workspace"))

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Settings = {
    AutoParry = false,
    AutoSpam = false,
    ShowAura = false,
}

local CONFIG = {
    ParryRange = 14,        -- alcance da espada. - e + ajustam
    RangeMin = 6,
    RangeMax = 30,
    ClickMin = 0.10,        -- intervalo min entre cliques na range
    ClickMax = 0.16,        -- intervalo max (humaniza)
    StopClosing = -5,       -- bola indo embora = para de clicar
    SpamInterval = 0.14,    -- auto spam seco
    PromoteDot = 0.70,      -- promocao de alvo por trajetoria
}

local State = {
    LastClickTime = 0,
    NextClickDelay = 0.12,
    ActiveBall = nil,
    LastPosition = Vector3.zero,
    PrevDistance = 0,
    SmoothedClosing = 0,
    LastTick = os.clock(),
    Clicks = 0,
    Confirms = 0,
    MainConnection = nil,
    ScreenGuiInstance = nil,
    MainFrame = nil,
    Indicator = nil,
    AuraDrawing = nil,
    LastDispatch = "init",
    LastGate = "--",
}

-- ==== CONFIRMACAO DE PARRY ====
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

-- ==== DISPATCH (MOUSE PRIMEIRO) ====
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

local function DoClick()
    if SendParryInput() then
        State.Clicks = State.Clicks + 1
    end
    State.LastClickTime = os.clock()
    State.NextClickDelay = CONFIG.ClickMin + math.random() * (CONFIG.ClickMax - CONFIG.ClickMin)
end

-- ==== DETECCAO DE BOLA ====
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

local function GetBallAttr(ball, attrName)
    local val = ball:GetAttribute(attrName)
    if val ~= nil then return val end
    if ball.Parent then val = ball.Parent:GetAttribute(attrName) end
    return val
end

local function CheckTargetByAttr(ball)
    for _, attr in ipairs({"target", "Target", "TargetPlayer"}) do
        local val = GetBallAttr(ball, attr)
        if val ~= nil and val ~= "" then
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
    end
    return false
end

local function GetActiveBall(root)
    local candidates, seen = {}, {}
    for _, folderName in ipairs({"Balls", "TrainingBalls", "Training"}) do
        local folder = Workspace:FindFirstChild(folderName)
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

    for _, ball in ipairs(candidates) do
        if CheckTargetByAttr(ball) then return ball, true end
    end

    local bestBall, bestScore = nil, -1
    for _, ball in ipairs(candidates) do
        local spd = ball.AssemblyLinearVelocity.Magnitude
        if spd > 5 then
            local dist = (ball.Position - root.Position).Magnitude
            if dist < 80 then
                local dot = ball.AssemblyLinearVelocity.Unit:Dot((root.Position - ball.Position).Unit)
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
    ScreenGui.Name = "phantomv3"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.IgnoreGuiInset = true
    if syn and syn.protect_gui then pcall(syn.protect_gui, ScreenGui) end
    ScreenGui.Parent = secureParent
    State.ScreenGuiInstance = ScreenGui

    -- Indicador de canto (NAO captura clique: Active = false)
    local indicator = Instance.new("TextLabel")
    indicator.Name = "indicator"
    indicator.AnchorPoint = Vector2.new(1, 1)
    indicator.Position = UDim2.new(1, -8, 1, -8)
    indicator.Size = UDim2.new(0, 210, 0, 46)
    indicator.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    indicator.BackgroundTransparency = 0.35
    indicator.BorderSizePixel = 0
    indicator.Font = Enum.Font.Code
    indicator.TextSize = 10
    indicator.TextColor3 = Color3.fromRGB(160, 210, 160)
    indicator.TextXAlignment = Enum.TextXAlignment.Left
    indicator.TextWrapped = true
    indicator.Active = false
    indicator.Text = "v3 | OFF | RNG 14\nCLK 0 | CONF 0 | TAXA --"
    indicator.Parent = ScreenGui
    State.Indicator = indicator
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(0, 4)

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 230, 0, 260)
    MainFrame.Position = UDim2.new(0.04, 0, 0.30, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui
    State.MainFrame = MainFrame
    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", MainFrame)
    stroke.Color = Color3.fromRGB(40, 40, 52)

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
    TitleText.Text = "PHANTOM v3 | P = mostrar/ocultar"
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

    local function SetUIVisible(visible)
        MainFrame.Visible = visible
        MainFrame.Active = visible
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
        return btn
    end

    CreateButton(1, "Auto Parry", false, function(v)
        Settings.AutoParry = v
        if v then
            SetUIVisible(false) -- esconde: clique simulado nao come botao
        end
    end)
    CreateButton(2, "Auto Spam", false, function(v) Settings.AutoSpam = v end)
    CreateButton(3, "Visual Aura", false, function(v) Settings.ShowAura = v end)

    local rangeLabel = Instance.new("TextLabel")
    rangeLabel.LayoutOrder = 4
    rangeLabel.Size = UDim2.new(1, 0, 0, 24)
    rangeLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    rangeLabel.BorderSizePixel = 0
    rangeLabel.Font = Enum.Font.Code
    rangeLabel.TextSize = 10
    rangeLabel.TextColor3 = Color3.fromRGB(140, 200, 255)
    rangeLabel.Text = "RANGE: 14  (teclas - e +)"
    rangeLabel.Parent = Container
    Instance.new("UICorner", rangeLabel).CornerRadius = UDim.new(0, 4)

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
        if State.AuraDrawing then pcall(function() State.AuraDrawing:Remove() end) State.AuraDrawing = nil end
        if State.ScreenGuiInstance then State.ScreenGuiInstance:Destroy() State.ScreenGuiInstance = nil end
    end)

    -- Teclas: P mostra/esconde | - e + ajustam range
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        if input.KeyCode == Enum.KeyCode.P then
            SetUIVisible(not MainFrame.Visible)
        elseif input.KeyCode == Enum.KeyCode.Minus or input.KeyCode == Enum.KeyCode.KeypadMinus then
            CONFIG.ParryRange = math.clamp(CONFIG.ParryRange - 1, CONFIG.RangeMin, CONFIG.RangeMax)
            rangeLabel.Text = "RANGE: " .. CONFIG.ParryRange .. "  (teclas - e +)"
        elseif input.KeyCode == Enum.KeyCode.Equal or input.KeyCode == Enum.KeyCode.KeypadPlus then
            CONFIG.ParryRange = math.clamp(CONFIG.ParryRange + 1, CONFIG.RangeMin, CONFIG.RangeMax)
            rangeLabel.Text = "RANGE: " .. CONFIG.ParryRange .. "  (teclas - e +)"
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

-- ==== LOOP PRINCIPAL ====
local renderEvent = RunService.PreRender or RunService.RenderStepped
local lastSpam = 0

State.MainConnection = renderEvent:Connect(function()
    local now = os.clock()

    if Settings.AutoSpam and (now - lastSpam) >= CONFIG.SpamInterval then
        lastSpam = now
        DoClick()
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local ball, isTarget = GetActiveBall(root)

    if not ball then
        State.ActiveBall = nil
        State.SmoothedClosing = 0
        State.LastGate = "SEM BOLA"
    else
        local dist = (ball.Position - root.Position).Magnitude
        local speed = ball.AssemblyLinearVelocity.Magnitude

        local dt = now - State.LastTick
        if dt <= 0 then dt = 0.001 end

        if State.ActiveBall ~= ball then
            State.ActiveBall = ball
            State.LastPosition = ball.Position
            State.PrevDistance = dist
            State.SmoothedClosing = 0
        else
            local rawClosing = (State.PrevDistance - dist) / dt
            State.PrevDistance = dist
            local alpha = math.clamp(dt * 30.0, 0.25, 0.90)
            State.SmoothedClosing = State.SmoothedClosing * (1 - alpha) + rawClosing * alpha
        end
        State.LastTick = now

        local closing = State.SmoothedClosing

        -- promocao de alvo por trajetoria
        if not isTarget and speed > 10 then
            local dot = ball.AssemblyLinearVelocity.Unit:Dot((root.Position - ball.Position).Unit)
            if dot > CONFIG.PromoteDot and dist < 50 and closing > 5 then
                isTarget = true
            end
        end

        -- logica central: RANGE LOCK
        if Settings.AutoParry and isTarget then
            if closing < CONFIG.StopClosing then
                State.LastGate = "BOLA SAIU"
            elseif dist <= CONFIG.ParryRange and closing > 0 then
                if (now - State.LastClickTime) >= State.NextClickDelay then
                    DoClick()
                    State.LastGate = "CLICOU"
                else
                    State.LastGate = "NA RANGE (cd)"
                end
            else
                State.LastGate = "LONGE (" .. string.format("%.1f", dist) .. ")"
            end
        elseif not Settings.AutoParry then
            State.LastGate = "OFF"
        else
            State.LastGate = "ALVO: OUTRO"
        end

        -- aura mostra o range real
        if State.AuraDrawing then
            if Settings.ShowAura then
                local sp, onScreen = Camera:WorldToViewportPoint(root.Position)
                if onScreen and sp.Z > 0 then
                    local edge = Camera:WorldToViewportPoint(root.Position + Camera.CFrame.RightVector * CONFIG.ParryRange)
                    State.AuraDrawing.Position = Vector2.new(sp.X, sp.Y)
                    State.AuraDrawing.Radius = math.clamp((Vector2.new(sp.X, sp.Y) - Vector2.new(edge.X, edge.Y)).Magnitude, 15, 900)
                    State.AuraDrawing.Color = isTarget and Color3.fromRGB(50, 255, 120) or Color3.fromRGB(80, 180, 255)
                    State.AuraDrawing.Visible = true
                else
                    State.AuraDrawing.Visible = false
                end
            else
                State.AuraDrawing.Visible = false
            end
        end

        -- telemetria de canto
        if State.Indicator then
            local rate = State.Clicks > 0 and math.floor((State.Confirms / State.Clicks) * 100) or 0
            State.Indicator.Text = string.format(
                "v3 | %s | RNG %d | %s\nDIST %.1f | VEL %.0f | CS %.1f\nCLK %d | CONF %d | TAXA %d%%",
                Settings.AutoParry and "ON" or "OFF",
                CONFIG.ParryRange,
                State.LastGate,
                dist, speed, closing,
                State.Clicks, State.Confirms, rate
            )
            State.Indicator.TextColor3 = Settings.AutoParry and Color3.fromRGB(120, 240, 140) or Color3.fromRGB(200, 120, 120)
        end
    end

    if State.Indicator and not ball then
        local rate = State.Clicks > 0 and math.floor((State.Confirms / State.Clicks) * 100) or 0
        State.Indicator.Text = string.format("v3 | %s | RNG %d | %s\nCLK %d | CONF %d | TAXA %d%%",
            Settings.AutoParry and "ON" or "OFF", CONFIG.ParryRange, State.LastGate,
            State.Clicks, State.Confirms, rate)
    end
end)

print("========================================")
print("  AUTO PARRY v3 - PHANTOM 1099")
print("  RANGE LOCK | UI CLICK-SAFE")
print("========================================")
print("  P      = mostrar/ocultar menu")
print("  - / +  = diminuir/aumentar range")
print("  TAXA no canto = CONFIRM / CLIQUES")
print("----------------------------------------")
print("  Morre com swing no vacuo? RANGE alto demais -> baixa (-)")
print("  Bola passa sem clique?   RANGE baixo demais -> sobe (+)")
print("  Comece em 14, ajuste de 1 em 1.")
print("========================================")
