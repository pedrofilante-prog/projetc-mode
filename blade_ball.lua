-- Blade Ball Auto Parry (v3 - GUI Forçada)
print("[V] Script iniciado!") -- Isso vai aparecer no console do YuB-X

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local parryAttempt = remotes:WaitForChild("ParryAttempt")

local enabled = true
local parryDelay = 0.15
local lastParryTime = 0

-- Tenta criar a GUI no PlayerGui (mais seguro que CoreGui em alguns executores)
local success, err = pcall(function()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ParryGuiV3"
    ScreenGui.ResetOnSpawn = false
    -- Tenta colocar no PlayerGui
    local pg = player:FindFirstChild("PlayerGui")
    if pg then
        ScreenGui.Parent = pg
    else
        ScreenGui.Parent = game:GetService("CoreGui")
    end

    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0, 200, 0, 120)
    Frame.Position = UDim2.new(0, 20, 0, 100)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Frame.Active = true
    Frame.Draggable = true
    Frame.Parent = ScreenGui

    local Title = Instance.new("TextLabel")
    Title.Size = UDim2.new(1, 0, 0, 30)
    Title.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    Title.Text = "Auto Parry V3"
    Title.TextColor3 = Color3.new(1, 1, 1)
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 14
    Title.Parent = Frame

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 180, 0, 40)
    ToggleBtn.Position = UDim2.new(0, 10, 0, 40)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    ToggleBtn.Text = "LIGADO"
    ToggleBtn.TextColor3 = Color3.new(1, 1, 1)
    ToggleBtn.Font = Enum.Font.GothamBold
    ToggleBtn.Parent = Frame

    local Status = Instance.new("TextLabel")
    Status.Name = "StatusLabel"
    Status.Size = UDim2.new(1, 0, 0, 30)
    Status.Position = UDim2.new(0, 0, 0, 85)
    Status.BackgroundTransparency = 1
    Status.Text = "Procurando..."
    Status.TextColor3 = Color3.new(1, 1, 0)
    Status.Font = Enum.Font.Gotham
    Status.TextSize = 12
    Status.Parent = Frame

    ToggleBtn.MouseButton1Click:Connect(function()
        enabled = not enabled
        if enabled then
            ToggleBtn.Text = "LIGADO"
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
        else
            ToggleBtn.Text = "DESLIGADO"
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        end
    end)
end)

if not success then
    print("[ERRO] Falha ao criar GUI:", err)
end

local function doParry()
    if tick() - lastParryTime < 0.2 then return end 
    lastParryTime = tick()
    pcall(function()
        parryAttempt:FireServer()
        print("[V] Parry Enviado!")
    end)
end

RunService.RenderStepped:Connect(function()
    if not enabled then return end

    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return end

    local character = player.Character
    local hrp = character and character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local pg = player:FindFirstChild("PlayerGui")
    local statusLabel = pg and pg:FindFirstChild("ParryGuiV3") and pg.ParryGuiV3:FindFirstChild("Frame") and pg.ParryGuiV3.Frame:FindFirstChild("StatusLabel")

    local foundBall = false
    for _, ball in pairs(ballsFolder:GetChildren()) do
        local isReal = ball:GetAttribute("realBall")
        if isReal then
            foundBall = true
            local velocity = ball.AssemblyLinearVelocity
            local distance = (hrp.Position - ball.Position).Magnitude

            if statusLabel then statusLabel.Text = "Bola a " .. math.floor(distance) .. "m" end

            if distance <= 25 and velocity.Magnitude > 0 then
                local directionToMe = (hrp.Position - ball.Position).Unit
                local dotProduct = velocity.Unit:Dot(directionToMe)
                if dotProduct > 0 then
                    if statusLabel then statusLabel.Text = "PERIGO! " .. math.floor(distance) .. "m" end
                    task.delay(parryDelay, doParry)
                end
            end
        end
    end
    
    if not foundBall and statusLabel then
        statusLabel.Text = "Nenhuma bola real."
    end
end)
