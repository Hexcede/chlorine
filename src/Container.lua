local Sandbox = require(script.Parent.Sandbox)
local Environment = require(script.Parent.Environment)

export type Sandbox = Sandbox.Sandbox
export type SandboxRule = Environment.SandboxRule
export type Environment = Environment.Environment

local Container = {}
Container.__index = Container

function Container.new()
	local self = setmetatable({}, Container)
	self._sandboxes = setmetatable({})
	return table.freeze(self):withEnvironment(Environment.new()):withSandbox(Sandbox.new())
end

function Container:withEnvironment(environment: Environment)
	environment = environment:clone()

	local clone = table.clone(self)

	local sandboxes = table.clone(clone._sandboxes)
	clone._sandboxes = sandboxes
	clone._environment = environment

	-- Bind all sandboxes to the new environment
	for sandbox, _boundEnv in pairs(sandboxes) do
		sandboxes[sandbox] = environment:boundTo(sandbox)
	end

	-- Return the clone and freeze it
	return table.freeze(clone)
end

function Container:withSandbox(sandbox: Sandbox)
	local clone = table.clone(self)

	-- Clone the sandboxes list & add the sandbox
	clone._sandboxes = table.clone(clone._sandboxes)
	clone._sandboxes[sandbox] = if clone._environment then clone._environment:boundTo(sandbox) else false

	-- Return the clone and freeze it
	return table.freeze(clone)
end

function Container:withoutSandbox(sandbox: Sandbox)
	local clone = table.clone(self)

	-- Clone the sandboxes list & remove the sandbox
	clone._sandboxes = table.clone(clone._sandboxes)
	clone._sandboxes[sandbox] = nil

	-- Return the clone and freeze it
	return table.freeze(clone)
end

function Container:withRules(...: SandboxRule)
	return self:withEnvironment(self._environment:withRules(...))
end
function Container:withoutRules(...: SandboxRule)
	return self:withEnvironment(self._environment:withoutRules(...))
end

function Container:TerminateAll()
	-- Terminate all sandboxes
	for sandbox, _boundEnv in pairs(self._sandboxes) do
		sandbox:Terminate()
	end
end

function Container:Spawn(sandbox: Sandbox, callback: (...any) -> ...any, ...: any): (boolean, string?)
	assert(self._sandboxes[sandbox], "Sandbox is not part of the container.")

	local environment = self._environment
	return sandbox:Spawn(environment:applyTo(callback), ...)
end

return Container