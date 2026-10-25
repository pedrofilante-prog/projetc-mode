-- Blade Ball Auto Parry (v4 - Sem Flood e com FireSignal)
print("[V] Script iniciado! Aguardando bolas...") -- Apenas um print para confirmar

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local parryAttempt = remotes:WaitForChild("ParryAttempt")
local parryButtonPress = remotes:FindFirstChild("ParryButtonPress") -- O BindableEvent

local enabled = true
local parryDelay = 0.15
local lastParryTime = 0

-- GUI de status (igual antes)
local pg = player:WaitForChild("PlayerGui")
local gui = pg:FindFirstChild("ParryGuiV3")
if not gui then
    gui = Instance.new("ScreenGui")
    gui.Name = "ParryGuiV3"
    gui.ResetOnSpawn = false
    gui.Parent = pg
    
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 150, 0, 50)
    frame.Position = UDim2.new(0, 20, 0, 100)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    
    local lbl = Instance.new("TextLabel", frame)
    lbl.Name = "Status"
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Ativo"
    lbl.TextColor3 = Color3.new(0, 1, 0)
    lbl.Font = Enum.Font.GothamBold
end

local statusLbl = gui.Frame:WaitForChild("Status")

local function doParry()
    if tick() - lastParryTime < 0.2 then return end 
    lastParryTime = tick()
    
    pcall(function()
        -- Tenta pelo BindableEvent primeiro (simula o clique real no jogo)
        if parryButtonPress then
            firesignal(parryButtonPress.OnClientEvent) 
        end
        -- Manda pro servidor também
        parryAttempt:FireServer()
    end)
end

RunService.RenderStepped:Connect(function()
    if not enabled then return end

    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end

    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for _, ball in pairs(ballsFolder:GetChildren()) do
        if ball:GetAttribute("realBall") then
            local velocity = ball.AssemblyLinearVelocity
            local distance = (hrp.Position - ball.Position).Magnitude

            if distance <= 25 and velocity.Magnitude > 0 then
                local dotProduct = velocity.Unit:Dot((hrp.Position - ball.Position).Unit)
                
                if dotProduct > 0 then
                    statusLbl.Text = "PERIGO! Parry!"
                    statusLbl.TextColor3 = Color3.new(1, 0, 0)
                    task.delay(parryDelay, doParry)
                else
                    statusLbl.Text = "Bola indo embora"
                    statusLbl.TextColor3 = Color3.new(1, 1, 0)
                end
            else
                statusLbl.Text = "Bola a " .. math.floor(distance) .. "m"
                statusLbl.TextColor3 = Color3.new(0, 1, 0)
            end
            break
        end
    end
end)
