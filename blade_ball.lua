--// BLADE BALL AUTO PARRY - PHANTOM / SAPPHIRE EDITION // --

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local BallFolder = workspace:WaitForChild("Balls")

--// CONFIG //
local Config = {
    Enabled = false,
    Accuracy = 75,
    RandomizeAccuracy = true,
    RandomRange = {25, 85},
    PredictionOffset = 0.08,
    MinDistance = 6.5
}

--// BYPASS E HOOK (CÉREBRO DO PARRY) //
local PF = nil
local _PARRY_PATCH = {
    keyTable = nil, transformFn = nil, netModule = nil,
    remoteId = nil, parryHash = nil, parryRemote = nil, ready = false,
}

task.spawn(function()
    pcall(function()
        local old_dinfo = debug.info
        hookfunction(getrenv().debug.info, function(f, t)
            if type(f) == "function" then return "[C]" 
            elseif f == 4 and t == "s" then return "ReplicatedStorage.Controllers.SwordsController " end
            return old_dinfo(f, t)
        end)
        local old_gfenv = getfenv
        hookfunction(getrenv().getfenv, function(l)
            if l ~= nil and type(l) == "number" then
                if l >= 1 and l <= 10 then return old_gfenv(10) end
            end
            return old_gfenv(l)
        end)
    end)

    pcall(function()
        local Controllers = ReplicatedStorage:WaitForChild("Controllers", 15)
        if not Controllers then return end
        local SC
        for _, child in ipairs(Controllers:GetChildren()) do
            if child.Name:sub(1, 15) == "SwordsController" then SC = child break end
        end
        if not SC then return end
        local PRY = SC:WaitForChild("PRY", 15)
        if not PRY then return end

        local Parry_Function = require(PRY)
        PF = Parry_Function
        
        local getupvals = debug.getupvalues or getupvalues
        if not getupvals then return end

        local ups = getupvals(Parry_Function)
        if not ups or #ups < 8 then return end

        _PARRY_PATCH.keyTable    = ups[3]
        _PARRY_PATCH.transformFn = ups[4]
        _PARRY_PATCH.netModule   = ups[6]
        _PARRY_PATCH.remoteId    = ups[7]
        _PARRY_PATCH.parryHash   = ups[8]

        local rok = pcall(function()
            _PARRY_PATCH.parryRemote = _PARRY_PATCH.netModule:RemoteEvent(_PARRY_PATCH.remoteId)
        end)
        if rok and _PARRY_PATCH.parryRemote then
            _PARRY_PATCH.ready = true
            print("[V] Bypass carregado! Pronto para o Parry.")
        end
    end)
end)

function _PARRY_PATCH.fire(curveCFrame, screenPositions, mouseLocation)
    if not _PARRY_PATCH.ready then return false end
    local kt = _PARRY_PATCH.keyTable
    if not kt then return false end
    local keyIndex = kt[3]
    local currentKey = kt[1] and kt[1][keyIndex]
    if not currentKey then return false end

    local tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey, "TIME")
    if not tok or not transformed then
        tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey)
        if not tok or not transformed then return false end
    end

    local serverTime = workspace:GetServerTimeNow() * 100
    local timeStr = tostring(math.floor(serverTime))
    local tc = {}
    for i = 1, #timeStr do
        local ki = (i - 1) % #transformed + 1
        local kb = string.byte(transformed, ki)
        local tb = (string.byte(timeStr, i) + i) % 256
        tc[i] = string.char(bit32.bxor(tb, kb))
    end
    local token = table.concat(tc)

    local fok = pcall(function()
        _PARRY_PATCH.parryRemote:FireServer(
            _PARRY_PATCH.parryHash, currentKey, token, 0.5,
            curveCFrame, screenPositions, mouseLocation, false
        )
    end)
    return fok
end

--// UI SIMPLES (PARA NÃO LOTAR O CÓDIGO) //
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoParryFinal"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 220, 0, 150)
Frame.Position = UDim2.new(0, 20, 0, 100)
Frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 30)
Title.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
Title.Text = "Auto Parry Pro"
Title.TextColor3 = Color3.new(1,1,1)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 14
Title.Parent = Frame
Instance.new("UICorner", Title).CornerRadius = UDim.new(0, 8)

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(0, 200, 0, 40)
Btn.Position = UDim2.new(0, 10, 0, 45)
Btn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
Btn.Text = "LIGAR"
Btn.TextColor3 = Color3.new(1,1,1)
Btn.Font = Enum.Font.GothamBold
Btn.TextSize = 16
Btn.Parent = Frame
Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 20)
Status.Position = UDim2.new(0, 0, 0, 95)
Status.BackgroundTransparency = 1
Status.Text = "Aguardando jogo..."
Status.TextColor3 = Color3.fromRGB(200, 200, 0)
Status.Font = Enum.Font.Gotham
Status.TextSize = 12
Status.Parent = Frame

Btn.MouseButton1Click:Connect(function()
    Config.Enabled = not Config.Enabled
    if Config.Enabled then
        Btn.Text = "DESLIGAR"
        Btn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        if _PARRY_PATCH.ready then Status.Text = "Ativo e Protegido" Status.TextColor3 = Color3.fromRGB(0, 255, 0) else Status.Text = "Erro no Bypass" end
    else
        Btn.Text = "LIGAR"
        Btn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        Status.Text = "Desligado"
        Status.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

--// LOOP DE DETECÇÃO E DISPARO //
local lastParry = 0

RunService.RenderStepped:Connect(function()
    if not Config.Enabled or not _PARRY_PATCH.ready then return end
    if tick() - lastParry < 0.15 then return end

    local balls = BallFolder:GetChildren()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, ball in ipairs(balls) do
        if ball:GetAttribute("realBall") or ball:FindFirstChild("zoomies") then
            local dist = (ball.Position - hrp.Position).Magnitude
            local vel = ball.AssemblyLinearVelocity
            if dist <= 25 and vel.Magnitude > 10 then
                local dot = vel.Unit:Dot((hrp.Position - ball.Position).Unit)
                if dot > 0 then
                    local acc = Config.Accuracy
                    if Config.RandomizeAccuracy then
                        acc = math.random(Config.RandomRange[1], Config.RandomRange[2])
                    end
                    if math.random(1, 100) <= acc then
                        -- CFrame da bola para o Curve Mode
                        local curve = CFrame.new(ball.Position, ball.Position + vel.Unit)
                        _PARRY_PATCH.fire(curve, {}, Vector2.new(mouse.X, mouse.Y))
                        lastParry = tick()
                    end
                end
            end
        end
    end
end)
