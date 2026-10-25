-- Hook Silencioso para o ParryAttempt
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local parryAttempt = remotes:WaitForChild("ParryAttempt")

print("[V] Hook ativado. Vá no jogo e clique no botão de Parry manualmente 1 vez.")

-- Hook no FireServer do RemoteEvent
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    
    -- Se for o nosso Remote de parry sendo disparado
    if self == parryAttempt and method == "FireServer" then
        local args = {...}
        local argString = ""
        
        -- Transforma os argumentos em texto para salvar
        for i, v in pairs(args) do
            argString = argString .. tostring(v) .. " | "
        end
        
        -- Salva num arquivo na pasta do executor
        if writefile then
            writefile("parry_args.txt", "Argumentos enviados: " .. argString)
            print("[V] Argumentos salvos no arquivo parry_args.txt!")
        end
        
        -- Não printa no console pra não travar o YuB-X
    end
    
    return oldNamecall(self, ...)
end)
