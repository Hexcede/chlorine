local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DevPackages = ReplicatedStorage.DevPackages
local Packages = ReplicatedStorage.Packages
local TestEZ = require(DevPackages.TestEZ)

TestEZ.TestBootstrap:run(script:GetChildren())