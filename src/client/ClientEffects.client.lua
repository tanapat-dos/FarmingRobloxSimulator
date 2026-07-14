local replicatedStorage = game:GetService("ReplicatedStorage")
local modules = replicatedStorage:WaitForChild("Modules")
local remotes = replicatedStorage:WaitForChild("RemoteEvents")

local clientEffects = modules.ClientEffects
local cachedModules = {}

for _,v in clientEffects:GetChildren() do
	if v:IsA("ModuleScript") then 
		cachedModules[v.Name] = require(v)
	end
end

remotes.ClientEffects.OnClientEvent:Connect(function(Action,Data)
	local found = cachedModules[Action]
	if found then
		found(Data)
	end
end)
