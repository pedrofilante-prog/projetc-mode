-- Blade Ball - Auto Parry (Remote Direct)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local parryAttempt = remotes:WaitForChild("ParryAttempt")

-- Configurações (Mude aqui se tomar kick)
local CONFIG = {
    parryDistance = 25,    -- Distância que ele começa a tentar o parry
    parryDelay = 0.15,     -- Atraso em segundos (ajuste fino pra enganar o anti-cheat)
    enabled = true
}

local lastParryTime = 0

-- Função que dispara o parry no servidor
local function doParry()
    if not CONFIG.enabled then return end
    
    -- Evita spam (rate limit do anti-cheat)
    if tick() - lastParryTime < 0.2 then return end 
    lastParryTime = tick()

    -- Dispara o RemoteEvent direto pro servidor
    pcall(function()
        parryAttempt:FireServer()
    end)
end

-- Loop principal (Roda a cada frame)
RunService.RenderStepped:Connect(function()
    if not CONFIG.enabled then return end

    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end

    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, ball in pairs(ballsFolder:GetChildren()) do
        -- Verifica se é a bola real (o jogo cria várias bolas falsas)
        local isReal = ball:GetAttribute("realBall")
        if isReal then
            local velocity = ball.AssemblyLinearVelocity
            local distance = (hrp.Position - ball.Position).Magnitude

            -- Se a bola está perto e vindo na direção do jogador
            if distance <= CONFIG.parryDistance and velocity.Magnitude > 0 then
                local directionToMe = (hrp.Position - ball.Position).Unit
                local dotProduct = velocity.Unit:Dot(directionToMe)

                -- Se dotProduct for > 0, a bola está vindo na sua direção
                if dotProduct > 0 then
                    task.delay(CONFIG.parryDelay, doParry)
                end
            end
        end
    end
end)
