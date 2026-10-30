-- ==== AUTO PARRY FIX v2 - PHANTOM 1099 ====
-- ==== DISPATCH: MOUSE FIRST (PROVADO NO YUB-X) ====

local cloneref = cloneref or function(obj) return obj end
local gethui = gethui or function() return nil end

local Players = cloneref(game:GetService("Players"))
local RunService = cloneref(game:GetService("RunService"))
local Stats = cloneref(game:GetService("Stats"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Workspace = cloneref(game:GetService("Workspace"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 10)

local Settings = {
    AutoParry = false,
    AutoSpam = false,
    ClashDetect = true,
    ShowAura = false,
}

local CONFIG = {
    BaseParryWindow = 0.28,
    ClashOpponentDistance = 40.0,
    ClashSpamCooldown = 0.105,
    SpamInterval = 0.15,
    PanicDistance = 25.0,
    JitterStdDev = 0.022,
}

local State = {
    LastParryTime = 0,
    LastSpamTime = 0,
    ActiveBall = nil,
    LastPosition = Vector3.zero,
    LastVelocity = Vector3.zero,
    PrevDistance = 0,
    SmoothedClosingSpeed = 0,
    LastTick = os.clock(),
    InClash = false,
    CurrentJitter = 0,
    ParryFiredVisualTick = 0,
    TargetCycleParried = false,
    HasParriedThisApproach = false,
    ParryIntervals = {},
    LastParrySpacingAvg = math.huge,
    MainConnection = nil,
    ScreenGuiInstance = nil,
    AuraDrawing = nil,
    ParryCount = 0,
    ConfirmedCount = 0,
    LastDispatch = "init",
}

local function GaussianRandom(mean, stddev)
    local u1 = math.max(math.random(), 1e-10)
    local u2 = math.random()
    return mean + math.sqrt(-2.0 * math.log(u1)) * math.cos(6.2831853 * u2) * stddev
end

-- ==== CONFIRMAÇÃO DE PARRY (FEEDBACK REAL) ====
pcall(function()
    local ParrySuccess = Remotes:FindFirstChild("ParrySuccess")
    if ParrySuccess and ParrySuccess:IsA("RemoteEvent") then
        ParrySuccess.OnClientEvent:Connect(function()
            State.ConfirmedCount = State.ConfirmedCount + 1
        end)
    end
    local ParrySuccessClient = Remotes:FindFirstChild("ParrySuccessClient")
    if ParrySuccessClient and ParrySuccessClient:IsA("BindableEvent") then
        ParrySuccessClient.Event:Connect(function()
            State.ConfirmedCount = State.ConfirmedCount + 1
        end)
    end
end)

-- ==== DISPATCH: MOUSE PRIMEIRO ====
local function SendParryInput()
    -- Prioridade 1: mouse1click (PROVADO no YuB-X pelo H4des)
    if mouse1click then
        pcall(mouse1click)
        State.LastDispatch = "m1click"
        return true
    end

    -- Prioridade 2: mouse1press + release
    if mouse1press then
        pcall(mouse1press)
        if mouse1release then task.defer(mouse1release) end
        State.LastDispatch = "m1press"
        return true
    end

    -- Prioridade 3: VirtualInputManager
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

local function ExecuteParry()
    local fireTime = os.clock()
    local gap = fireTime - State.LastParryTime

    if gap < 3.0 then
        table.insert(State.ParryIntervals, gap)
        if #State.ParryIntervals > 4 then table.remove(State.ParryIntervals, 1) end
        local sum = 0
        for _, v in ipairs(State.ParryIntervals) do sum = sum + v end
        State.LastParrySpacingAvg = sum / #State.ParryIntervals
    else
        State.ParryIntervals = {}
        State.LastParrySpacingAvg = math.huge
    end

    if SendParryInput() then
        State.ParryCount = State.ParryCount + 1
    end

    State.LastParryTime = fireTime
    State.ParryFiredVisualTick = fireTime
    State.TargetCycleParried = true
    State.HasParriedThisApproach = true
    State.CurrentJitter = math.clamp(GaussianRandom(0.003, CONFIG.JitterStdDev), -0.038, 0.048)
end

-- ==== DETECÇÃO DE BOLA (ENXUTA) ====
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
    if ball.Parent then
        val = ball.Parent:GetAttribute(attrName)
    end
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
            local strVal = tostring(val)
            if strVal == LocalPlayer.Name or strVal == LocalPlayer.DisplayName or strVal == tostring(LocalPlayer.UserId) then
                return true
            end
            return false
        end
    end
    return false
end

local function GetActiveBall(root)
    local candidates = {}
    local seen = {}

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

    for _, ball in ipairs(candidates) do
        if CheckTargetByAttr(ball) then return ball, true end
    end

    local bestBall, bestScore = nil, -1
    for _, ball in ipairs(candidates) do
        local vel = ball.AssemblyLinearVelocity
        local spd = vel.Magnitude
        if spd > 5 then
            local dist = (ball.Position - root.Position).Magnitude
            if dist < 80 then
                local dot = vel.Unit:Dot((root.Position - ball.Position).Unit)
                if dot > 0.70 then
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

local function GetClosestOpponent(myPos)
    local minDist, closest = math.huge, nil
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - myPos).Magnitude
                if dist < minDist then
                    minDist = dist
                    closest = player
                end
            end
        end
    end
    return closest, minDist
end

local function GetPing()
    local ok, ping = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return ok and ping or 0.055
end

-- ==== UI ====
local TelemetryLabel = nil

local function GenerateRandomIdentifier()
    local str = ""
    for _ = 1, 8 do str = str .. string.char(math.random(97, 122)) end
    return str
end

local function CreateUI()
    local secureParent = gethui()
    if not secureParent then
        local ok, core = pcall(function() return cloneref(game:GetService("CoreGui")) end)
        secureParent = (ok and core) or LocalPlayer:WaitForChild("PlayerGui")
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = GenerateRandomIdentifier()
    ScreenGui.ResetOnSpawn = false
    if syn and syn.protect_gui then pcall(syn.protect_gui, ScreenGui) end
    ScreenGui.Parent = secureParent
    State.ScreenGuiInstance = ScreenGui

    local MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 240, 0, 430)
    MainFrame.Position = UDim2.new(0.04, 0, 0.25, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui

    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new("UIStroke", MainFrame)
    stroke.Color = Color3.fromRGB(40, 40, 52)

    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 32)
    TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 6)

    local TitleText = Instance.new("TextLabel")
    TitleText.Size = UDim2.new(1, -10, 1, 0)
    TitleText.Position = UDim2.new(0, 10, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "BLADE BALL // PHANTOM FIX v2"
    TitleText.TextColor3 = Color3.fromRGB(215, 215, 225)
    TitleText.TextSize = 11
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    TitleText.Parent = TitleBar

    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local Container = Instance.new("Frame")
    Container.Size = UDim2.new(1, -16, 1, -42)
    Container.Position = UDim2.new(0, 8, 0, 36)
    Container.BackgroundTransparency = 1
    Container.Parent = MainFrame

    local layout = Instance.new("UIListLayout", Container)
    layout.Padding = UDim.new(0, 5)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    TelemetryLabel = Instance.new("TextLabel")
    TelemetryLabel.LayoutOrder = 0
    TelemetryLabel.Size = UDim2.new(1, 0, 0, 110)
    TelemetryLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    TelemetryLabel.BorderSizePixel = 0
    TelemetryLabel.Font = Enum.Font.Code
    TelemetryLabel.TextSize = 10
    TelemetryLabel.TextColor3 = Color3.fromRGB(160, 210, 160)
    TelemetryLabel.TextWrapped = true
    TelemetryLabel.TextXAlignment = Enum.TextXAlignment.Left
    TelemetryLabel.Text = "AGUARDANDO...\nCLIQUES: 0 | CONFIRMADOS: 0"
    TelemetryLabel.Parent = Container
    Instance.new("UICorner", TelemetryLabel).CornerRadius = UDim.new(0, 4)

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

    CreateButton(1, "Auto Parry", Settings.AutoParry, function(v) Settings.AutoParry = v end)
    CreateButton(2, "Auto Spam", Settings.AutoSpam, function(v) Settings.AutoSpam = v end)
    CreateButton(3, "Clash Detect", Settings.ClashDetect, function(v) Settings.ClashDetect = v end)
    CreateButton(4, "Visual Aura", Settings.ShowAura, function(v) Settings.ShowAura = v end)

    -- BOTÃO DE TESTE: prova que o clique funciona
    local testBtn = Instance.new("TextButton")
    testBtn.LayoutOrder = 8
    testBtn.Size = UDim2.new(1, 0, 0, 30)
    testBtn.BackgroundColor3 = Color3.fromRGB(25, 45, 70)
    testBtn.BorderSizePixel = 0
    testBtn.Font = Enum.Font.GothamBold
    testBtn.TextSize = 11
    testBtn.TextColor3 = Color3.fromRGB(140, 200, 255)
    testBtn.Text = "TEST CLICK (3 cliques)"
    testBtn.AutoButtonColor = false
    testBtn.Parent = Container
    Instance.new("UICorner", testBtn).CornerRadius = UDim.new(0, 4)

    testBtn.MouseButton1Click:Connect(function()
        task.spawn(function()
            for i = 1, 3 do
                SendParryInput()
                State.ParryCount = State.ParryCount + 1
                task.wait(0.15)
            end
        end)
    end)

    local killBtn = Instance.new("TextButton")
    killBtn.LayoutOrder = 9
    killBtn.Size = UDim2.new(1, 0, 0, 30)
    killBtn.BackgroundColor3 = Color3.fromRGB(55, 20, 20)
    killBtn.BorderSizePixel = 0
    killBtn.Font = Enum.Font.GothamBold
    killBtn.TextSize = 11
    killBtn.TextColor3 = Color3.fromRGB(255, 110, 110)
    killBtn.Text = "FINALIZAR SCRIPT [KILL]"
    killBtn.AutoButtonColor = false
    killBtn.Parent = Container
    Instance.new("UICorner", killBtn).CornerRadius = UDim.new(0, 4)

    killBtn.MouseButton1Click:Connect(function()
        if State.MainConnection then
            State.MainConnection:Disconnect()
            State.MainConnection = nil
        end
        if State.AuraDrawing then
            pcall(function() State.AuraDrawing:Remove() end)
            State.AuraDrawing = nil
        end
        if State.ScreenGuiInstance then
            State.ScreenGuiInstance:Destroy()
            State.ScreenGuiInstance = nil
        end
    end)
end

CreateUI()

pcall(function()
    if Drawing and Drawing.new then
        local circle = Drawing.new("Circle")
        circle.Thickness = 2.5
        circle.NumSides = 56
        circle.Filled = false
        circle.Transparency = 0.70
        circle.Color = Color3.fromRGB(80, 180, 255)
        circle.Visible = false
        State.AuraDrawing = circle
    end
end)

-- ==== LOOP PRINCIPAL ====
local renderEvent = RunService.PreRender or RunService.RenderStepped

State.MainConnection = renderEvent:Connect(function()
    local now = os.clock()

    -- Auto Spam: clica direto, sem detecção (prova de input + treino)
    if Settings.AutoSpam and (now - State.LastSpamTime) >= CONFIG.SpamInterval then
        State.LastSpamTime = now
        SendParryInput()
        State.ParryCount = State.ParryCount + 1
    end

    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local ball, isTarget = GetActiveBall(root)

    if TelemetryLabel then
        local justParried = (now - State.ParryFiredVisualTick) < 0.30
        if ball then
            local dist = (ball.Position - root.Position).Magnitude
            local spd = ball.AssemblyLinearVelocity.Magnitude
            TelemetryLabel.Text = string.format(
                "%sBOLA: %s | ALVO: %s\nDIST: %.1f | VEL: %.1f\nCLIQUES: %d | CONFIRM: %d\nDISP: %s",
                justParried and ">> PARRY! <<\n" or "",
                ball.Name, isTarget and "VOCE" or "OUTRO",
                dist, spd,
                State.ParryCount, State.ConfirmedCount,
                State.LastDispatch
            )
            TelemetryLabel.TextColor3 = justParried and Color3.fromRGB(80, 255, 255)
                or (isTarget and Color3.fromRGB(100, 240, 120) or Color3.fromRGB(200, 200, 120))
        else
            TelemetryLabel.Text = string.format("BOLA: NAO DETECTADA\nCLIQUES: %d | CONFIRM: %d\nDISP: %s", State.ParryCount, State.ConfirmedCount, State.LastDispatch)
            TelemetryLabel.TextColor3 = Color3.fromRGB(200, 100, 100)
        end
    end

    if not Settings.AutoParry or not ball then
        State.InClash = false
        State.ActiveBall = nil
        State.TargetCycleParried = false
        State.HasParriedThisApproach = false
        return
    end

    local dt = now - State.LastTick
    if dt <= 0 then dt = 0.001 end
    State.LastTick = now

    local currentPos = ball.Position

    if State.ActiveBall ~= ball then
        State.ActiveBall = ball
        State.LastPosition = currentPos
        State.LastVelocity = ball.AssemblyLinearVelocity
        State.PrevDistance = (currentPos - root.Position).Magnitude
        State.TargetCycleParried = false
        State.HasParriedThisApproach = false
        State.SmoothedClosingSpeed = 0
        return
    end

    local currentVel = ball.AssemblyLinearVelocity
    if currentVel.Magnitude < 0.5 then
        local fallback = (currentPos - State.LastPosition) / math.max(dt, 0.008)
        if fallback.Magnitude < 2000 then currentVel = fallback end
    end

    State.LastPosition = currentPos
    State.LastVelocity = currentVel

    local distance = (currentPos - root.Position).Magnitude
    local speed = currentVel.Magnitude

    local rawClosing = (State.PrevDistance - distance) / dt
    State.PrevDistance = distance
    local csAlpha = math.clamp(dt * 25.0, 0.18, 0.90)
    State.SmoothedClosingSpeed = State.SmoothedClosingSpeed * (1 - csAlpha) + rawClosing * csAlpha
    local closingSpeed = State.SmoothedClosingSpeed

    local toPlayer = (root.Position - currentPos).Unit
    local approachDot = (speed > 1.2) and currentVel.Unit:Dot(toPlayer) or 0
    local isMovingTowardsMe = approachDot > 0.05

    -- Promoção de alvo: bola vindo rápido em mim = minha, mesmo sem atributo
    if not isTarget and approachDot > 0.70 and speed > 10 and closingSpeed > 5 and distance < 50 then
        isTarget = true
    end

    -- Clash
    local closestPlayer, closestOpponentDist = GetClosestOpponent(root.Position)
    local isOpponentNear = closestPlayer ~= nil and closestOpponentDist <= CONFIG.ClashOpponentDistance
    local inTrueClash = false
    if Settings.ClashDetect and isTarget and isOpponentNear then
        local oppRoot = closestPlayer.Character and closestPlayer.Character:FindFirstChild("HumanoidRootPart")
        if oppRoot and speed > 2.0 then
            local velTowardsMe = currentVel.Unit:Dot((root.Position - oppRoot.Position).Unit)
            if distance <= 35.0 and velTowardsMe > 0.30 then
                inTrueClash = true
            end
        end
        if State.InClash and distance < 45.0 and (now - State.LastParryTime) < 2.0 then
            inTrueClash = true
        end
    end

    if inTrueClash then
        State.InClash = true
        if (now - State.LastParryTime) >= CONFIG.ClashSpamCooldown then
            ExecuteParry()
        end
        return
    else
        State.InClash = false
    end

    if not isTarget then
        State.TargetCycleParried = false
        return
    end

    if State.TargetCycleParried then
        local sinceParry = now - State.LastParryTime
        if sinceParry < 0.65 then return
        elseif distance > 35.0 or sinceParry > 1.2 then
            State.TargetCycleParried = false
        else
            return
        end
    end

    if closingSpeed < -8.0 and distance > 20.0 then
        State.HasParriedThisApproach = false
        return
    end

    if not isMovingTowardsMe then
        State.HasParriedThisApproach = false
        return
    end

    if State.HasParriedThisApproach then
        if (now - State.LastParryTime) < 0.60 then return
        else State.HasParriedThisApproach = false end
    end

    -- Janela de disparo
    local ping = GetPing()
    local highSpeedBonus = math.clamp((speed - 300) / 400, 0, 0.10)
    local targetWindow = math.max(ping * 0.80 + CONFIG.BaseParryWindow + highSpeedBonus + State.CurrentJitter, 0.20)
    local timeToImpact = (closingSpeed > 0.5) and (distance / closingSpeed) or math.huge
    local effectiveCS = math.max(closingSpeed, speed * 0.5)
    local distThreshold = math.clamp(effectiveCS * targetWindow, math.clamp(8.0 + speed * 0.07, 8.0, 18.0), 200.0)

    if State.AuraDrawing then
        if Settings.ShowAura then
            local screenPos, onScreen = Camera:WorldToViewportPoint(root.Position)
            if onScreen and screenPos.Z > 0 then
                local edgePos = Camera:WorldToViewportPoint(root.Position + Camera.CFrame.RightVector * distThreshold)
                State.AuraDrawing.Position = Vector2.new(screenPos.X, screenPos.Y)
                State.AuraDrawing.Radius = math.clamp((Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(edgePos.X, edgePos.Y)).Magnitude, 18, 800)
                State.AuraDrawing.Color = isTarget and Color3.fromRGB(50, 255, 120) or Color3.fromRGB(80, 180, 255)
                State.AuraDrawing.Visible = true
            else
                State.AuraDrawing.Visible = false
            end
        else
            State.AuraDrawing.Visible = false
        end
    end

    local shouldParry = false
    if timeToImpact <= targetWindow then shouldParry = true end
    if distance <= distThreshold and closingSpeed > 1.0 then shouldParry = true end
    if distance <= CONFIG.PanicDistance and closingSpeed > 0 then shouldParry = true end

    if shouldParry and (now - State.LastParryTime) >= 0.18 then
        ExecuteParry()
    end
end)

print("========================================")
print("  AUTO PARRY FIX v2 - PHANTOM 1099")
print("  DISPATCH: MOUSE FIRST (YUB-X PROVADO)")
print("========================================")
print("  [1] CLIQUE EM 'TEST CLICK' DENTRO DO JOGO")
print("      -> se a espada girar, o input funciona")
print("  [2] LIGUE 'AUTO PARRY' COM BOLA VINDO")
print("  [3] WATCH 'CONFIRM' SUBIR = PARRY REAL")
print("  [4] 'AUTO SPAM' = CLIQUE SECO P/ TESTE")
print("========================================")
