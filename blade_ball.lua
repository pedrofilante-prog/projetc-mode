-- Blade Ball Auto Parry (Básico)
local player = game.Players.LocalPlayer
local runService = game:GetService("RunService")
local workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local config = {
    parryDistance = 25,
    parryTime = 0.5,
    enabled = true
}

local virtualUser = game:GetService("VirtualUser")
local function doParry()
    if not config.enabled then return end
    -- Simula o clique do mouse para dar parry
    virtualUser:Button1Down(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
    virtualUser:Button1Up(Vector2.new(0,0), workspace.CurrentCamera.CFrame)
end

-- Loop principal
runService.RenderStepped:Connect(function()
    if not config.enabled then return end
    
    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name == "Ball" and obj:FindFirstChild("Position") then
            local ballPos = obj.Position
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local dist = (char.HumanoidRootPart.Position - ballPos).Magnitude
                
                -- Se a bola estiver perto e vindo na direção do jogador
                if dist <= config.parryDistance then
                    local velocity = obj.AssemblyLinearVelocity
                    local direction = (char.HumanoidRootPart.Position - ballPos).Unit
                    local dot = velocity:Dot(direction)
                    
                    -- Se a bola estiver vindo em nossa direção (dot > 0)
                    if dot > 0 then
                        doParry()
                    end
                end
            end
        end
    end
end)
