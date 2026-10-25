--// BLADE BALL AUTO PARRY - FORCE INJECTION // --

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local BallFolder = workspace:WaitForChild("Balls")

local Config = { Enabled = false }

local _PARRY_PATCH = {
    keyTable = nil,
    transformFn = nil,
    parryHash = nil,
    parryRemote = nil,
    ready = false,
}

--// CAPTURA DIRETA (SEM METATABLE) //
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}
    
    if method == "FireServer" and typeof(self) == "Instance" and self:IsA("RemoteEvent") then
        -- Verifica se o remote enviado tem os 8 argumentos do parry
        if #args == 8 and type(args[2]) == "string" and type(args[4]) == "number" and typeof(args[5]) == "CFrame" then
            if not _PARRY_PATCH.parryRemote then
                _PARRY_PATCH.parryRemote = self
                _PARRY_PATCH.parryHash = args[1]
                getgenv()._autoParryUI_Status("Remote Capturado!", Color3.fromRGB(255, 200, 0))
            end
        end
    end
    return oldNamecall(self, ...)
end)

--// FORÇAR LEITURA DA KEYTABLE (TENTATIVA DIRETA) //
task.spawn(function()
    task.wait(2)
    local ok, err = pcall(function()
        local Controllers = ReplicatedStorage:WaitForChild("Controllers", 10)
        local SC
        for _, child in ipairs(Controllers:GetChildren()) do
            if child.Name:find("SwordsController") then SC = child break end
        end
        if not SC then return end
        
        local PRY = SC:WaitForChild("PRY", 10)
        if not PRY then return end
        
        local Parry_Function = require(PRY)
        local getupvals = debug.getupvalues or getupvalues
        if not getupvals then return end

        local ups = getupvals(Parry_Function)
        if ups and #ups >= 8 then
            _PARRY_PATCH.keyTable    = ups[3]
            _PARRY_PATCH.transformFn = ups[4]
            _PARRY_PATCH.parryHash   = ups[8] or _PARRY_PATCH.parryHash
            getgenv()._autoParryUI_Status("Ativo e Protegido", Color3.fromRGB(0, 255, 0))
        else
            getgenv()._autoParryUI_Status("Args Capturados (Sem Key)", Color3.fromRGB(255, 150, 0))
        end
    end)
end)

function _PARRY_PATCH.fire()
    if not _PARRY_PATCH.ready and not _PARRY_PATCH.parryRemote then return false end
    
    -- Se a KeyTable não existe, dispara o remote direto (pode ou não funcionar no servidor)
    if not _PARRY_PATCH.keyTable then
        pcall(function()
            _PARRY_PATCH.parryRemote:FireServer(
                _PARRY_PATCH.parryHash, "Key", "Token", 0.5,
                CFrame.new(), {}, Vector2.new(0,0), false
            )
        end)
        return true
    end

    local kt = _PARRY_PATCH.keyTable
    local keyIndex = kt[1]
    local currentKey = kt[2] and kt[2][keyIndex]
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

    pcall(function()
        _PARRY_PATCH.parryRemote:FireServer(
            _PARRY_PATCH.parryHash, currentKey, token, 0.5,
            CFrame.new(), {}, Vector2.new(0,0), false
        )
    end)
    return true
end

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
Status.Text = "Dê um Parry Manual!"
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
            Status.Text = "Ativo e Protegido" 
            Status.TextColor3 = Color3.fromRGB(0, 255, 0) 
        elseif _PARRY_PATCH.parryRemote then
            Status.Text = "Remote OK (Sem Key)"
            Status.TextColor3 = Color3.fromRGB(255, 150, 0)
        else
            Status.Text = "Aguardando Captura..."
            Status.TextColor3 = Color3.fromRGB(200, 200, 0)
        end
    else
        Btn.Text = "LIGAR"
        Btn.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
        Status.Text = "Desligado"
        Status.TextColor3 = Color3.fromRGB(150, 150, 150)
    end
end)

--// LOOP DE DETECÇÃO //
local lastParry = 0
RunService.RenderStepped:Connect(function()
    if not Config.Enabled then return end
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
                    if _PARRY_PATCH.parryRemote then
                        _PARRY_PATCH.fire()
                        lastParry = tick()
                    end
                end
            end
        end
    end
end)
