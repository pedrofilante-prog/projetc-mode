--// BLADE BALL AUTO PARRY - SAPPHIRE/PHANTOM HYBRID v2 // --

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local BallFolder = workspace:WaitForChild("Balls")

local Config = { Enabled = false }
local _PARRY_PATCH = { ready = false }

--// UI SIMPLES //
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoParryHybrid"
ScreenGui.Parent = CoreGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.new(0, 220, 0, 100)
Frame.Position = UDim2.new(0, 20, 0, 100)
Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Frame.Active = true
Frame.Draggable = true
Frame.Parent = ScreenGui
Instance.new("UICorner", Frame).CornerRadius = UDim.new(0, 8)

local Btn = Instance.new("TextButton")
Btn.Size = UDim2.new(0, 200, 0, 40)
Btn.Position = UDim2.new(0, 10, 0, 10)
Btn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
Btn.Text = "LIGAR"
Btn.TextColor3 = Color3.new(1,1,1)
Btn.Font = Enum.Font.GothamBold
Btn.Parent = Frame
Instance.new("UICorner", Btn).CornerRadius = UDim.new(0, 6)

local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, 0, 0, 20)
Status.Position = UDim2.new(0, 0, 0, 60)
Status.BackgroundTransparency = 1
Status.Text = "Aguardando..."
Status.TextColor3 = Color3.fromRGB(200, 200, 0)
Status.Parent = Frame

Btn.MouseButton1Click:Connect(function()
    Config.Enabled = not Config.Enabled
    if Config.Enabled then
        Btn.Text = "DESLIGAR"
        Btn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        if _PARRY_PATCH.ready then Status.Text = "Ativo e Protegido" Status.TextColor3 = Color3.fromRGB(0, 255, 0) else Status.Text = "Erro: Sem Parry" end
    else
        Btn.Text = "LIGAR"
        Btn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        Status.Text = "Desligado"
        Status.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

--// INICIALIZAÇÃO (BYPASS MÚLTIPLO) //
task.spawn(function()
    task.wait(1)
    
    -- 1. Tenta o método do debug.info + getupvalues (original)
    local ok1 = pcall(function()
        local Controllers = ReplicatedStorage:WaitForChild("Controllers", 5)
        local SC = Controllers:FindFirstChild("SwordsController")
        if not SC then return end
        local PRY = SC:WaitForChild("PRY", 5)
        local Parry_Function = require(PRY)
        
        local ups = debug.getupvalues(Parry_Function) or getupvalues(Parry_Function)
        if ups and #ups >= 8 then
            _PARRY_PATCH.keyTable    = ups[3]
            _PARRY_PATCH.transformFn = ups[4]
            _PARRY_PATCH.netModule   = ups[6]
            _PARRY_PATCH.remoteId    = ups[7]
            _PARRY_PATCH.parryHash   = ups[8]
            if _PARRY_PATCH.netModule and _PARRY_PATCH.remoteId then
                _PARRY_PATCH.parryRemote = _PARRY_PATCH.netModule:RemoteEvent(_PARRY_PATCH.remoteId)
                _PARRY_PATCH.ready = true
            end
        end
    end)

    -- 2. Se falhou, tenta o getfenv
    if not _PARRY_PATCH.ready then
        pcall(function()
            local Controllers = ReplicatedStorage:WaitForChild("Controllers", 5)
            local SC = Controllers:FindFirstChild("SwordsController")
            if not SC then return end
            local PRY = SC:WaitForChild("PRY", 5)
            local Parry_Function = require(PRY)
            local env = getfenv(Parry_Function)
            if env then
                _PARRY_PATCH.netModule = env.netModule
                _PARRY_PATCH.remoteId = env.remoteId
                _PARRY_PATCH.parryHash = env.parryHash
                _PARRY_PATCH.transformFn = env.transformFn
                _PARRY_PATCH.keyTable = env.keyTable
                if _PARRY_PATCH.netModule and _PARRY_PATCH.remoteId then
                    _PARRY_PATCH.parryRemote = _PARRY_PATCH.netModule:RemoteEvent(_PARRY_PATCH.remoteId)
                    _PARRY_PATCH.ready = true
                end
            end
        end)
    end

    -- 3. Se ainda falhou, usa o getrawmetatable (método de PC)
    if not _PARRY_PATCH.ready then
        pcall(function()
            local oldNamecall
            oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
                local method = getnamecallmethod()
                if method == "FireServer" and tostring(self):find("PRY") then
                    local args = {...}
                    if #args >= 8 then
                        _PARRY_PATCH.parryRemote = self
                        _PARRY_PATCH.parryHash = args[1]
                        _PARRY_PATCH.keyTable = {args[2]}
                        _PARRY_PATCH.transformFn = function() return "token" end
                        _PARRY_PATCH.ready = true
                        return oldNamecall(self, ...)
                    end
                end
                return oldNamecall(self, ...)
            end)
        end)
    end

    if _PARRY_PATCH.ready then
        print("[V] Bypass Inicializado com Sucesso!")
    else
        print("[V] Falha no Bypass. O YuB-X não conseguiu ler o PRY.")
    end
end)

function _PARRY_PATCH.fire()
    if not _PARRY_PATCH.ready then return false end
    
    -- Se for o método 3 (hook), a gente só dispara o remote direto
    if _PARRY_PATCH.parryRemote and not _PARRY_PATCH.keyTable[1] then
        pcall(function()
            _PARRY_PATCH.parryRemote:FireServer(
                _PARRY_PATCH.parryHash, "Key", "Token", 0.5,
                CFrame.new(), {}, Vector2.new(0,0), false
            )
        end)
        return true
    end

    -- Método original (1 e 2)
    local kt = _PARRY_PATCH.keyTable
    if not kt or not kt[1] then return false end
    local currentKey = kt[1][kt[3]]
    if not currentKey then return false end

    local tok, transformed = pcall(_PARRY_PATCH.transformFn, currentKey, "TIME")
    if not tok or not transformed then return false end

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

    pcall(function()
        _PARRY_PATCH.parryRemote:FireServer(
            _PARRY_PATCH.parryHash, currentKey, token, 0.5,
            CFrame.new(), {}, Vector2.new(0,0), false
        )
    end)
    return true
end

--// LOOP DE DETECÇÃO //
local lastParry = 0
RunService.RenderStepped:Connect(function()
    if not Config.Enabled or not _PARRY_PATCH.ready then return end
    if tick() - lastParry < 0.15 then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, ball in ipairs(BallFolder:GetChildren()) do
        if ball:GetAttribute("realBall") or ball:FindFirstChild("zoomies") then
            local dist = (ball.Position - hrp.Position).Magnitude
            local vel = ball.AssemblyLinearVelocity
            if dist <= 25 and vel.Magnitude > 10 then
                local dot = vel.Unit:Dot((hrp.Position - ball.Position).Unit)
                if dot > 0 then
                    _PARRY_PATCH.fire()
                    lastParry = tick()
                end
            end
        end
    end
end)
