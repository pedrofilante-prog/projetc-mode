--// BLADE BALL AUTO PARRY - SYDRA EMULATION // --

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ParryAttempt = Remotes:WaitForChild("ParryAttempt")
local BallFolder = workspace:WaitForChild("Balls")

-- CONFIGURAÇÕES (Baseadas no Sydra)
local Settings = {
    Accuracy = 75,              -- Igual ao Sydra (75% de chance de tentar)
    RandomAccuracyMin = 25,
    RandomAccuracyMax = 85,
    ParryDistance = 15,
    Cooldown = 0.15,
}

local CachedArgs = nil
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    -- Escuta o seu clique manual pra pegar os argumentos exatos
    if self == ParryAttempt and method == "FireServer" then
        CachedArgs = args
    end
    return OldNamecall(self, ...)
end)

local lastParry = 0

local function tryParry()
    if tick() - lastParry < Settings.Cooldown then return end
    lastParry = tick()
    
    -- A matemática da "Accuracy": Só tenta se o número aleatório for menor que a precisão
    local currentAccuracy = math.random(Settings.RandomAccuracyMin, Settings.RandomAccuracyMax)
    if math.random(1, 100) > currentAccuracy then
        return -- Falhou de propósito (para enganar o anti-cheat)
    end
    
    -- Se tiver os argumentos que você deu no clique manual, usa eles
    if CachedArgs then
        pcall(function()
            ParryAttempt:FireServer(unpack(CachedArgs))
        end)
    else
        -- Fallback pra quando você ainda não clicou manual
        pcall(function()
            ParryAttempt:FireServer()
        end)
    end
end

RunService.RenderStepped:Connect(function()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local closestBall = nil
    local minDist = Settings.ParryDistance

    for _, ball in pairs(BallFolder:GetChildren()) do
        if ball:GetAttribute("realBall") or ball:FindFirstChild("zoomies") then
            local dist = (ball.Position - hrp.Position).Magnitude
            local vel = ball.AssemblyLinearVelocity
            
            -- Verifica se a bola está vindo na sua direção (Curve Detection básico)
            if dist < minDist and vel.Magnitude > 15 then
                local dot = vel.Unit:Dot((hrp.Position - ball.Position).Unit)
                if dot > 0 then
                    closestBall = ball
                    minDist = dist
                end
            end
        end
    end

    if closestBall then
        tryParry()
    end
end)
