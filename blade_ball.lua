--// BLADE BALL AUTO PARRY BYPASS // --
--// PHANTOM 1099 - CLEAN BUILD // --

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

--// VETORES DE ATAQUE //
local ParryAttempt = Remotes:WaitForChild("ParryAttempt")
local ParryButtonPress = Remotes:FindFirstChild("ParryButtonPress") -- BindableEvent
local BallFolder = workspace:WaitForChild("Balls")

--// CONFIGURAÇÃO //
local Settings = {
    UseBindableFirst = true;      -- Prioriza o Bindable (mais seguro)
    FallbackToRaw = true;         -- Se Bindable falhar, usa raw com args sniffados
    PredictionOffset = 0.08;      -- Ajuste fino de timing (segundos)
    MaxBallSpeed = 350;           -- Limite de velocidade para ativar
    MinDistance = 6.5;            -- Distância mínima para parry
}

--// ARGUMENT SNIFFER (FALLBACK) //
-- Captura os args reais quando o jogo faz um parry legítimo
local CachedArgs = nil
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if self == ParryAttempt and method == "FireServer" then
        -- Cacheia os argumentos exatos que o jogo enviou
        CachedArgs = args
    end
    
    return OldNamecall(self, ...)
end)

--// LÓGICA DE DETECÇÃO DE BOLA //
local function getTargetBall()
    local balls = BallFolder:GetChildren()
    for _, ball in ipairs(balls) do
        if ball:GetAttribute("realBall") or ball:FindFirstChild("zoomies") then
            local vel = ball.AssemblyLinearVelocity
            if vel and vel.Magnitude > 10 then
                return ball, vel.Magnitude
            end
        end
    end
    return nil, 0
end

--// FUNÇÃO DE DISPARO //
local function executeParry()
    -- TENTATIVA 1: BindableEvent (Caminho Legítimo Interno)
    if Settings.UseBindableFirst and ParryButtonPress and ParryButtonPress:IsA("BindableEvent") then
        pcall(function()
            ParryButtonPress:Fire()
        end)
        return
    end
    
    -- TENTATIVA 2: Raw FireServer com Args Cacheados
    if Settings.FallbackToRaw and CachedArgs then
        pcall(function()
            ParryAttempt:FireServer(unpack(CachedArgs))
        end)
        return
    end
    
    -- TENTATIVA 3: Raw com Timestamp (Último recurso)
    pcall(function()
        ParryAttempt:FireServer(os.clock(), LocalPlayer.Character:GetPivot())
    end)
end

--// LOOP PRINCIPAL DE AUTO PARRY //
RunService.RenderStepped:Connect(function(dt)
    local ball, speed = getTargetBall()
    if not ball or speed < 10 then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    
    local dist = (ball.Position - hrp.Position).Magnitude
    local closingSpeed = speed
    
    -- Predição simples: ativa quando a bola está dentro do raio efetivo
    -- considerando o tempo de reação simulado
    if dist <= Settings.MinDistance + (closingSpeed * Settings.PredictionOffset) then
        executeParry()
    end
end)

--// CLEANUP //
game:BindToClose(function()
    if OldNamecall then
        -- Restaurar metamethod se necessário (executores modernos fazem auto-cleanup)
    end
end)
