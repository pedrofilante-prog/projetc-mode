--// BLADE BALL AUTO PARRY - RAYCAST PREDICTION // --

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local BallFolder = workspace:WaitForChild("Balls")
local Camera = workspace.CurrentCamera

local Config = { Enabled = false }
local _PARRY_PATCH = { ready = false, parryFunc = nil }

--// INJEÇÃO VIA GETCONNECTIONS //
task.spawn(function()
    task.wait(2)
    local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
    if not Remotes then return end
    local ParryButtonPress = Remotes:FindFirstChild("ParryButtonPress")
    if not ParryButtonPress then return end

    local ok, conns = pcall(getconnections, ParryButtonPress.Event)
    if ok and conns then
        for _, conn in pairs(conns) do
            local func = conn.Function
            if func and not isourclosure(func) then
                _PARRY_PATCH.parryFunc = func
                _PARRY_PATCH.ready = true
                getgenv()._autoParryUI_Status("Ativo e Calibrado", Color3.fromRGB(0, 255, 0))
                break
            end
        end
    end
end)

--// INTERFACE //
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "AutoParryAzure"
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
Status.Text = "Aguardando Injeção..."
Status.TextColor3 = Color3.fromRGB(200, 200, 0)
Status.Parent = Frame

getgenv()._autoParryUI_Status = function(text, color)
    Status.Text = text
    Status.TextColor3 = color
end

Btn.MouseButton1Click:Connect(function()
    Config.Enabled = not Config.Enabled
    if Config.Enabled then
        Btn.Text = "DESLIGAR"
        Btn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        if _PARRY_PATCH.ready then 
            Status.Text = "Ativo e Calibrado" 
            Status.TextColor3 = Color3.fromRGB(0, 255, 0) 
        else
            Status.Text = "Falha"
            Status.TextColor3 = Color3.fromRGB(255, 0, 0)
        end
    else
        Btn.Text = "LIGAR"
        Btn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        Status.Text = "Desligado"
        Status.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

--// LOOP DE PREDIÇÃO (RAYCAST) //
local lastParry = 0
RunService.RenderStepped:Connect(function()
    if not Config.Enabled or not _PARRY_PATCH.ready then return end
    if tick() - lastParry < 0.2 then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, ball in ipairs(BallFolder:GetChildren()) do
        if ball:GetAttribute("realBall") or ball:FindFirstChild("zoomies") then
            local ballPos = ball.Position
            local ballVel = ball.AssemblyLinearVelocity
            
            -- Só tenta se a bola estiver vindo pra você (Dot > 0)
            local direction = (hrp.Position - ballPos).Unit
            local dot = ballVel.Unit:Dot(direction)

            if dot > 0.3 and ballVel.Magnitude > 10 then
                local dist = (hrp.Position - ballPos).Magnitude

                -- Predição da distância futura
                if dist <= 35 then
                    -- Faz um Raycast da bola até o jogador pra ver se tem parede no meio
                    local params = RaycastParams.new()
                    params.FilterDescendantsInstances = {char, ball}
                    params.FilterType = Enum.RaycastFilterType.Exclude
                    
                    local rayResult = workspace:Raycast(ballPos, ballVel * 0.2, params)
                    
                    -- Se o Raycast não bater em nada (tem visão limpa), ou se estiver perto o suficiente:
                    if not rayResult or dist <= 15 then
                        -- Adiciona um delay baseado na distância/velocidade pra dar o timing perfeito
                        local timeToReach = dist / (ballVel.Magnitude or 1)
                        task.delay(math.max(0, timeToReach - 0.1), function()
                            if Config.Enabled then
                                pcall(function()
                                    _PARRY_PATCH.parryFunc() -- Chama a função real do jogo
                                end)
                            end
                        end)
                        lastParry = tick()
                    end
                end
            end
        end
    end
end)
