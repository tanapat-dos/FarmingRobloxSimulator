-- Mounts BackpackPanelUi (menu bar also opens it). Keep script so Rojo/Studio stay in sync.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BackpackPanelUi = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("BackpackPanelUi"))

local player = Players.LocalPlayer or Players.PlayerAdded:Wait()
BackpackPanelUi.mount(player)
