--// BLADE BALL AUTO PARRY BYPASS - QWEN FIX // --

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ParryAttempt = Remotes:WaitForChild("ParryAttempt")
local ParryButtonPress = Remotes:FindFirstChild("ParryButtonPress")
local BallFolder = workspace:WaitForChild("Balls")

local Settings = {
    UseBindableFirst = true,
    FallbackToRaw = true,
    PredictionOffset = 0.08,
    MaxBallSpeed = 350,
    MinDistance = 6.5,
}

local CachedArgs = nil
local OldNamecall
OldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if self == ParryAttempt and method == "FireServer" then
        CachedArgs = args
        if writefile then
            local str = ""
            for i, v in pairs(args) do str = str .. tostring(v) .. " | " end
            writefile("qwen_args.txt", "Args: " .. str)
        end
    end
    return OldNamecall(self, ...)
end)

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

local function executeParry()
    -- Se temos argumentos cacheados de um parry manual, usamos eles
    if Settings.FallbackToRaw and CachedArgs then
        pcall(function()
            ParryAttempt:FireServer(unpack(CachedArgs))
        end)
        return
    end

    -- Senão, tenta o Bindable Event
    if Settings.UseBindableFirst and ParryButtonPress then
        pcall(function()
            if firesignal then
                firesignal(ParryButtonPress.OnClientEvent)
            else
                ParryButtonPress:Fire()
            end
        end)
        return
    end
end

RunService.RenderStepped:Connect(function(dt)
    local ball, speed = getTargetBall()
    if not ball or speed < 10 then return end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local dist = (ball.Position - hrp.Position).Magnitude
    local closingSpeed = speed

    -- Se o CachedArgs não existir ainda, avisa no console uma vez (ou não)
    if not CachedArgs then
        return
    end

    if dist <= Settings.MinDistance + (closingSpeed * Settings.PredictionOffset) then
        executeParry()
    end
end)
