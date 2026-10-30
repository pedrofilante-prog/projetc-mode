-- ==== AUTO PARRY REBUILD - PHANTOM 1099 ====
-- ==== BASED ON H4DES STRUCTURE | YUB-X OPTIMIZED ====

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

-- ==== CONFIGURATION ====
local Settings = {
    AutoParry = false,
    AutoSpam = false,
    CurveDetect = true,
    ClashDetect = true,
    ShowAura = false,
}

local CONFIG = {
    BaseParryWindow = 0.25,
    SafetyOffset = 0.020,
    CurveThreshold = 2.8,
    MinParryDistance = 16.5,
    MaxParryDistance = 145.0,
    ClashDistance = 35.0,
    ClashOpponentDistance = 40.0,
    ClashSpamCooldown = 0.105,
    SpamInterval = 0.15,
    JitterStdDev = 0.022,
}

-- ==== STATE ====
local State = {
    LastParryTime = 0,
    ActiveBall = nil,
    LastPosition = Vector3.zero,
    LastVelocity = Vector3.zero,
    SmoothedAcc = Vector3.zero,
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
    ParryFunction = nil,
    CachedArgs = nil,
    LastSpamTime = 0,
}

-- ==== DISPATCH METHODS ====
local _dispatchMode = "init"
local _apiDiag = ""
local _execName = "?"

pcall(function()
    local fn = identifyexecutor or getexecutorname or get_executor_name
    if fn then
        local n = fn()
        if type(n) == "string" then _execName = n end
    end
end)

local _hasM1C = mouse1click ~= nil
local _hasM1P = mouse1press ~= nil
local _hasGetConn = getconnections ~= nil

_apiDiag = "m1c:" .. (_hasM1C and "Y" or "N")
    .. " m1p:" .. (_hasM1P and "Y" or "N")
    .. " gc:" .. (_hasGetConn and "Y" or "N")
    .. " EX:" .. _execName

-- Method 1: GetConnections (Find real parry function)
local function findParryFunction()
    if not _hasGetConn then return nil end
    if not Remotes then return nil end
    
    local ParryButtonPress = Remotes:FindFirstChild("ParryButtonPress")
    if not ParryButtonPress or not ParryButtonPress:IsA("BindableEvent") then return nil end
    
    local success, connections = pcall(getconnections, ParryButtonPress.Event)
    if not success or not connections then return nil end
    
    for _, conn in ipairs(connections) do
        if typeof(conn.Function) == "function" then
            return conn.Function
        end
    end
    
    return nil
end

-- Method 2: Hook __namecall for args cache
local function setupNamecallHook()
    if not hookmetamethod or not newcclosure then return end
    
    local ParryAttempt = Remotes and Remotes:FindFirstChild("ParryAttempt")
    if not ParryAttempt then return end
    
    pcall(function()
        local OldNamecall
        OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if self == ParryAttempt and method == "FireServer" then
                State.CachedArgs = {...}
            end
            return OldNamecall(self, ...)
        end))
    end)
end

-- Initialize dispatch methods
task.spawn(function()
    State.ParryFunction = findParryFunction()
    
    if State.ParryFunction then
        _dispatchMode = "ready [getconn]"
        print("[PHANTOM] ✓ Parry function found via getconnections")
    else
        print("[PHANTOM] ⚠ getconnections failed, using fallback methods")
    end
    
    setupNamecallHook()
    
    if State.CachedArgs then
        print("[PHANTOM] ✓ Args cache active")
    end
end)

-- ==== DISPATCH EXECUTION ====
local function SendParryInput()
    -- Priority 1: Direct function call via getconnections
    if State.ParryFunction then
        pcall(State.ParryFunction)
        _dispatchMode = "getconn"
        return
    end
    
    -- Priority 2: BindableEvent fire
    local ParryButtonPress = Remotes and Remotes:FindFirstChild("ParryButtonPress")
    if ParryButtonPress and ParryButtonPress:IsA("BindableEvent") then
        pcall(function() ParryButtonPress:Fire() end)
        _dispatchMode = "bindable"
        return
    end
    
    -- Priority 3: RemoteEvent with cached args
    if State.CachedArgs then
        local ParryAttempt = Remotes and Remotes:FindFirstChild("ParryAttempt")
        if ParryAttempt then
            pcall(function() ParryAttempt:FireServer(unpack(State.CachedArgs)) end)
            _dispatchMode = "remote+args"
            return
        end
    end
    
    -- Priority 4: mouse1click (fallback)
    if mouse1click then
        pcall(mouse1click)
        _dispatchMode = "m1click"
        return
    end
    
    -- Priority 5: mouse1press
    if mouse1press then
        pcall(mouse1press)
        if mouse1release then task.defer(mouse1release) end
        _dispatchMode = "m1press"
        return
    end
    
    -- Priority 6: VirtualInputManager
    local vimOk, vim = pcall(function() return game:GetService("VirtualInputManager") end)
    if vimOk and vim then
        pcall(function() vim:SendMouseButtonEvent(0, 0, 0, true, game, 0) end)
        task.defer(function()
            pcall(function() vim:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
        end)
        _dispatchMode = "vim"
        return
    end
    
    _dispatchMode = "NO_METHOD"
end

-- ==== HELPER FUNCTIONS ====
local function GaussianRandom(mean, stddev)
    local u1 = math.max(math.random(), 1e-10)
    local u2 = math.random()
    return mean + math.sqrt(-2.0 * math.log(u1)) * math.cos(6.2831853 * u2) * stddev
end

local function GenerateRandomIdentifier()
    local str = ""
    for _ = 1, 8 do
        str = str .. string.char(math.random(97, 122))
    end
    return str
end

local function ResolveBasePart(inst)
    if inst:IsA("BasePart") then
        return inst
    elseif inst:IsA("Model") then
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

local function IsValidBall(inst)
    if IsCharacter(inst) then return nil end
    return ResolveBasePart(inst)
end

local function GetBallAttr(ball, attrName)
    local val = ball:GetAttribute(attrName)
    if val ~= nil then return val end
    if ball.Parent then
        val = ball.Parent:GetAttribute(attrName)
        if val ~= nil then return val end
    end
    return nil
end

local function CheckTargetByAttr(ball, root)
    for _, attr in ipairs({"target", "Target", "TargetPlayer"}) do
        local val = GetBallAttr(ball, attr)
        if val ~= nil and val ~= "" then
            if typeof(val) == "Instance" then
                if val == LocalPlayer or val == LocalPlayer.Character then
                    return true
                end
                return false
            end
            local strVal = tostring(val)
            local isMe = strVal == LocalPlayer.Name
                or strVal == LocalPlayer.DisplayName
                or strVal == tostring(LocalPlayer.UserId)
            if isMe then return true else return false end
        end
    end
    return false
end

local function GetActiveBall(root)
    local candidates = {}
    local seen = {}
    
    local ballFolders = {
        Workspace:FindFirstChild("Balls"),
        Workspace:FindFirstChild("TrainingBalls"),
        Workspace:FindFirstChild("Training"),
    }
    
    for _, folder in ipairs(ballFolders) do
        if folder then
            for _, child in ipairs(folder:GetChildren()) do
                local part = IsValidBall(child)
                if part and not seen[part] then
                    seen[part] = true
                    table.insert(candidates, part)
                end
            end
        end
    end
    
    for _, child in ipairs(Workspace:GetChildren()) do
        local part = IsValidBall(child)
        if part and not seen[part] then
            local name = child.Name:lower()
            if name:find("ball") or name:find("projectile") or child:GetAttribute("realBall") then
                seen[part] = true
                table.insert(candidates, part)
            end
        end
    end
    
    if #candidates == 0 then return nil, false end
    
    for _, ball in ipairs(candidates) do
        if CheckTargetByAttr(ball, root) then
            return ball, true
        end
    end
    
    local bestBall = nil
    local bestScore = -1
    
    for _, ball in ipairs(candidates) do
        local vel = ball.AssemblyLinearVelocity
        local spd = vel.Magnitude
        
        if spd > 5 then
            local dist = (ball.Position - root.Position).Magnitude
            if dist < 80 then
                local toMe = (root.Position - ball.Position).Unit
                local dot = vel.Unit:Dot(toMe)
                
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
    
    if bestBall then
        return bestBall, true
    end
    
    local closestBall = nil
    local closestDist = math.huge
    
    for _, ball in ipairs(candidates) do
        local dist = (ball.Position - root.Position).Magnitude
        if dist < closestDist then
            closestDist = dist
            closestBall = ball
        end
    end
    
    return closestBall, false
end

local function GetClosestOpponent(myRoot)
    local minDist = math.huge
    local closestPlayer = nil
    local myPos = myRoot.Position
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - myPos).Magnitude
                if dist < minDist then
                    minDist = dist
                    closestPlayer = player
                end
            end
        end
    end
    
    return closestPlayer, minDist
end

local function GetPing()
    local success, ping = pcall(function()
        return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    end)
    return success and ping or 0.055
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
    
    SendParryInput()
    
    State.LastParryTime = fireTime
    State.ParryFiredVisualTick = fireTime
    State.TargetCycleParried = true
    State.HasParriedThisApproach = true
    State.CurrentJitter = math.clamp(GaussianRandom(0.003, CONFIG.JitterStdDev), -0.038, 0.048)
end

-- ==== UI ====
local TelemetryLabel = nil

local function CreateUI()
    local secureParent = gethui()
    if not secureParent then
        local success, core = pcall(function() return cloneref(game:GetService("CoreGui")) end)
        if success and core then
            secureParent = core
        else
            secureParent = LocalPlayer:WaitForChild("PlayerGui")
        end
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = GenerateRandomIdentifier()
    ScreenGui.ResetOnSpawn = false
    
    if syn and syn.protect_gui then
        pcall(syn.protect_gui, ScreenGui)
    end
    
    ScreenGui.Parent = secureParent
    
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = GenerateRandomIdentifier()
    MainFrame.Size = UDim2.new(0, 230, 0, 450)
    State.ScreenGuiInstance = ScreenGui
    MainFrame.Position = UDim2.new(0.04, 0, 0.25, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Parent = ScreenGui
    
    local MainCorner = Instance.new("UICorner")
    MainCorner.CornerRadius = UDim.new(0, 6)
    MainCorner.Parent = MainFrame
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Color = Color3.fromRGB(40, 40, 52)
    Stroke.Thickness = 1
    Stroke.Parent = MainFrame
    
    local TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 32)
    TitleBar.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
    
    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 6)
    TitleCorner.Parent = TitleBar
    
    local TitleText = Instance.new("TextLabel")
    TitleText.Size = UDim2.new(1, -10, 1, 0)
    TitleText.Position = UDim2.new(0, 10, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "BLADE BALL // PHANTOM 1099"
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
    
    local ListLayout = Instance.new("UIListLayout")
    ListLayout.Padding = UDim.new(0, 5)
    ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    ListLayout.Parent = Container
    
    TelemetryLabel = Instance.new("TextLabel")
    TelemetryLabel.LayoutOrder = 0
    TelemetryLabel.Size = UDim2.new(1, 0, 0, 124)
    TelemetryLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 28)
    TelemetryLabel.BorderSizePixel = 0
    TelemetryLabel.Font = Enum.Font.Code
    TelemetryLabel.TextSize = 10
    TelemetryLabel.TextColor3 = Color3.fromRGB(160, 210, 160)
    TelemetryLabel.TextWrapped = true
    TelemetryLabel.TextXAlignment = Enum.TextXAlignment.Left
    TelemetryLabel.Text = "BOLA: Aguardando...\nDIST: -- | VEL: --"
    TelemetryLabel.Parent = Container
    
    local telemCorner = Instance.new("UICorner")
    telemCorner.CornerRadius = UDim.new(0, 4)
    telemCorner.Parent = TelemetryLabel
    
    local function CreateButton(order, text, defaultState, callback)
        local btn = Instance.new("TextButton")
        btn.Name = GenerateRandomIdentifier()
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
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 4)
        corner.Parent = btn
        
        local active = defaultState
        btn.MouseButton1Click:Connect(function()
            active = not active
            btn.BackgroundColor3 = active and Color3.fromRGB(30, 65, 40) or Color3.fromRGB(25, 25, 32)
            btn.Text = string.format("%s: %s", text, active and "[ON]" or "[OFF]")
            callback(active)
        end)
    end
    
    CreateButton(1, "Auto Parry", Settings.AutoParry, function(v) Settings.AutoParry = v end)
    CreateButton(2, "Auto Spam", Settings.AutoSpam, function(v) Settings.AutoSpam = v end)
    CreateButton(3, "Clash Detect", Settings.ClashDetect, function(v) Settings.ClashDetect = v end)
    CreateButton(4, "Visual Aura", Settings.ShowAura, function(v) Settings.ShowAura = v end)
    
    local killBtn = Instance.new("TextButton")
    killBtn.Name = GenerateRandomIdentifier()
    killBtn.LayoutOrder = 10
    killBtn.Size = UDim2.new(1, 0, 0, 30)
    killBtn.BackgroundColor3 = Color3.fromRGB(55, 20, 20)
    killBtn.BorderSizePixel = 0
    killBtn.Font = Enum.Font.GothamBold
    killBtn.TextSize = 11
    killBtn.TextColor3 = Color3.fromRGB(255, 110, 110)
    killBtn.Text = "FINALIZAR SCRIPT [KILL]"
    killBtn.AutoButtonColor = false
    killBtn.Parent = Container
    
    local killCorner = Instance.new("UICorner")
    killCorner.CornerRadius = UDim.new(0, 4)
    killCorner.Parent = killBtn
    
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

-- ==== MAIN LOOP ====
State.MainConnection = RunService.PreRender:Connect(function()
    local char = LocalPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    -- Auto Spam Logic
    if Settings.AutoSpam then
        local now = os.clock()
        if (now - State.LastSpamTime) >= CONFIG.SpamInterval then
            State.LastSpamTime = now
            SendParryInput()
        end
    end
    
    if not Settings.AutoParry then
        if TelemetryLabel then
            TelemetryLabel.Text = "AUTO PARRY: OFF\n\n" .. _apiDiag
            TelemetryLabel.TextColor3 = Color3.fromRGB(200, 100, 100)
        end
        return
    end
    
    local ball, isTarget = GetActiveBall(root)
    if not ball then
        State.InClash = false
        State.ActiveBall = nil
        State.TargetCycleParried = false
        State.HasParriedThisApproach = false
        if TelemetryLabel then
            TelemetryLabel.Text = "BOLA: Nao Detectada\nDIST: -- | VEL: --\n\n" .. _dispatchMode
            TelemetryLabel.TextColor3 = Color3.fromRGB(200, 100, 100)
        end
        return
    end
    
    local now = os.clock()
    local dt = now - State.LastTick
    if dt <= 0 then dt = 0.001 end
    State.LastTick = now
    
    local currentPos = ball.Position
    
    if State.ActiveBall ~= ball then
        State.ActiveBall = ball
        State.LastPosition = currentPos
        local initVel = ball.AssemblyLinearVelocity
        State.LastVelocity = initVel
        local initDist = (currentPos - root.Position).Magnitude
        State.PrevDistance = initDist
        State.TargetCycleParried = false
        State.HasParriedThisApproach = false
        
        local initSpeed = initVel.Magnitude
        if initSpeed > 1.0 and initDist > 0.1 then
            local toPlayerUnit = (root.Position - currentPos).Unit
            local initCS = math.max(initVel.Unit:Dot(toPlayerUnit) * initSpeed, 0)
            State.SmoothedClosingSpeed = initCS
        else
            State.SmoothedClosingSpeed = 0
        end
        return
    end
    
    local currentVel = ball.AssemblyLinearVelocity
    if currentVel.Magnitude < 0.5 then
        local fallback = (currentPos - State.LastPosition) / math.max(dt, 0.008)
        if fallback.Magnitude < 2000 then
            currentVel = fallback
        end
    end
    
    local rawAcc = (currentVel - State.LastVelocity) / dt
    State.SmoothedAcc = State.SmoothedAcc:Lerp(rawAcc, 0.40)
    local currentAcc = State.SmoothedAcc
    
    State.LastPosition = currentPos
    State.LastVelocity = currentVel
    
    local distance = (currentPos - root.Position).Magnitude
    local speed = currentVel.Magnitude
    
    local closestPlayer, closestOpponentDist = GetClosestOpponent(root)
    
    local rawClosingSpeed = (State.PrevDistance - distance) / dt
    State.PrevDistance = distance
    
    local csAlpha = math.clamp(dt * 25.0, 0.18, 0.90)
    State.SmoothedClosingSpeed = State.SmoothedClosingSpeed * (1 - csAlpha) + rawClosingSpeed * csAlpha
    local closingSpeed = State.SmoothedClosingSpeed
    
    local toPlayer = (root.Position - currentPos).Unit
    local approachDot = (speed > 1.2) and currentVel.Unit:Dot(toPlayer) or 0
    local isMovingTowardsMe = approachDot > 0.05
    
    local isOpponentNear = closestPlayer ~= nil and closestOpponentDist <= CONFIG.ClashOpponentDistance
    local isBallClose = distance <= CONFIG.ClashDistance
    local isSpeedActive = speed >= 5.0
    local isClashIncoming = false
    
    local clashOppRoot = nil
    if isOpponentNear and closestPlayer.Character then
        clashOppRoot = closestPlayer.Character:FindFirstChild("HumanoidRootPart")
        if clashOppRoot and speed > 2.0 then
            local oppToMe = (root.Position - clashOppRoot.Position).Unit
            local velTowardsMe = currentVel.Unit:Dot(oppToMe)
            isClashIncoming = velTowardsMe > 0.30
        end
    end
    
    local recentParried = (now - State.LastParryTime) < 1.8
    local isClashByFrequency = State.LastParrySpacingAvg < 0.6 and #State.ParryIntervals >= 3 and recentParried and isOpponentNear and isClashIncoming
    local isClashByPosition = isOpponentNear and isBallClose and isSpeedActive and isClashIncoming and isMovingTowardsMe
    local clashEntry = Settings.ClashDetect and isTarget and (isClashByFrequency or isClashByPosition)
    local clashPersist = State.InClash and isOpponentNear and distance < 45.0 and (now - State.LastParryTime) < 2.0 and isTarget
    local inTrueClash = clashEntry or clashPersist
    
    if TelemetryLabel then
        local justParried = (now - State.ParryFiredVisualTick) < 0.30
        local oppName = closestPlayer and closestPlayer.Name or "Nenhum"
        local clashReason = isClashByFrequency and "FREQ" or "POS"
        local avgDisplay = State.LastParrySpacingAvg == math.huge and 99.9 or State.LastParrySpacingAvg
        local clashStatusStr = inTrueClash and string.format("[CLASH(%s): VS %s]", clashReason, oppName) or string.format("[NEUTRO | OP:%.1fm]", closestOpponentDist)
        
        if justParried then
            TelemetryLabel.Text = string.format("PARRY EXECUTADO!\nDIST: %.1f | VEL: %.1f | CS: %.1f\n%s\n\nDISP: %s", distance, speed, closingSpeed, clashStatusStr, _dispatchMode)
            TelemetryLabel.TextColor3 = Color3.fromRGB(80, 255, 255)
        else
            TelemetryLabel.Text = string.format("BOLA: %s | ALVO: %s\nDIST: %.1f | VEL: %.1f | CS: %.1f\n%s\n\nDISP: %s | %s",
                ball.Name,
                isTarget and "VOCE" or "OUTRO",
                distance,
                speed,
                closingSpeed,
                clashStatusStr,
                _dispatchMode,
                _apiDiag
            )
            TelemetryLabel.TextColor3 = inTrueClash and Color3.fromRGB(255, 60, 60) or (isTarget and Color3.fromRGB(100, 240, 120) or Color3.fromRGB(200, 200, 120))
        end
    end
    
    if not isTarget then
        State.InClash = false
        State.TargetCycleParried = false
        return
    end
    
    if inTrueClash then
        State.InClash = true
        if (now - State.LastParryTime) >= CONFIG.ClashSpamCooldown then
            ExecuteParry()
        end
        return
    else
        if State.InClash and (distance > 45.0 or not isOpponentNear) then
            State.InClash = false
        end
    end
    
    if State.TargetCycleParried then
        local sinceParry = now - State.LastParryTime
        if sinceParry < 0.65 then
            return
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
        if (now - State.LastParryTime) < 0.60 then
            return
        else
            State.HasParriedThisApproach = false
        end
    end
    
    local ping = GetPing()
    local pingOffset = ping * 0.80
    local highSpeedBonus = math.clamp((speed - 300) / 400, 0, 0.10)
    local baseWindow = 0.28 + highSpeedBonus
    local speedVariance = math.clamp(speed / 2500.0, 0, 0.03) * (GaussianRandom(0, 1) > 0 and 1 or -1)
    local targetTriggerWindow = math.max(pingOffset + baseWindow + speedVariance + State.CurrentJitter, 0.20)
    local timeToImpact = (closingSpeed > 0.5) and (distance / closingSpeed) or math.huge
    local effectiveCS = math.max(closingSpeed, speed * 0.5)
    local minThreshold = math.clamp(8.0 + speed * 0.07, 8.0, 18.0)
    local dynamicDistanceThreshold = math.clamp(effectiveCS * targetTriggerWindow, minThreshold, 200.0)
    
    if State.AuraDrawing then
        if Settings.ShowAura and root then
            local rootPos = root.Position
            local screenPos, onScreen = Camera:WorldToViewportPoint(rootPos)
            if onScreen and screenPos.Z > 0 then
                local edgePos = Camera:WorldToViewportPoint(rootPos + Camera.CFrame.RightVector * dynamicDistanceThreshold)
                local screenRadius = math.clamp((Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(edgePos.X, edgePos.Y)).Magnitude, 18, 800)
                State.AuraDrawing.Position = Vector2.new(screenPos.X, screenPos.Y)
                State.AuraDrawing.Radius = screenRadius
                State.AuraDrawing.Visible = true
                if inTrueClash then
                    State.AuraDrawing.Color = Color3.fromRGB(255, 50, 50)
                elseif isTarget then
                    State.AuraDrawing.Color = Color3.fromRGB(50, 255, 120)
                else
                    State.AuraDrawing.Color = Color3.fromRGB(80, 180, 255)
                end
            else
                State.AuraDrawing.Visible = false
            end
        else
            State.AuraDrawing.Visible = false
        end
    end
    
    local shouldParry = false
    
    if timeToImpact <= targetTriggerWindow then
        shouldParry = true
    end
    
    if distance <= dynamicDistanceThreshold and closingSpeed > 1.0 then
        shouldParry = true
    end
    
    local emergencyDist = math.clamp(7.0 + speed * 0.05, 7.0, 16.0)
    if distance <= emergencyDist and closingSpeed > 0 then
        shouldParry = true
    end
    
    if shouldParry then
        if (now - State.LastParryTime) >= 0.18 then
            ExecuteParry()
        end
    end
end)

-- ==== INITIALIZATION ====
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

print("========================================")
print("  AUTO PARRY REBUILD - PHANTOM 1099")
print("  YUB-X OPTIMIZED | BASED ON H4DES")
print("========================================")
print("  [✓] GETCONNECTIONS PRIMARY METHOD")
print("  [✓] BINDABLE FIRE BACKUP")
print("  [✓] NAMECALL HOOK FOR ARGS")
print("  [✓] AUTO SPAM TOGGLE ADDED")
print("  [✓] SIMPLIFIED GATE LOGIC")
print("========================================")
