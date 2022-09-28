local Container = require(script.Container)
local Sandbox = require(script.Sandbox)
local Environment = require(script.Environment)
local Rules = require(script.Rules)
local Queries = require(script.Queries)
local Reflection = require(script.Reflection)
local Primitives = require(script.Primitives)

local Chlorine = {
	Container = Container;
	Sandbox = Sandbox;
	Environment = Environment;
	Rules = Rules;
	Queries = Queries;
	Reflection = Reflection;
	Primitives = Primitives;
}

return table.freeze(Chlorine)