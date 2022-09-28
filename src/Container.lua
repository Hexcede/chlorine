local Sandbox = require(script.Parent.Sandbox)
local Environment = require(script.Parent.Environment)

export type Sandbox = Sandbox.Sandbox
export type SandboxRule = Environment.SandboxRule
export type Environment = Environment.Environment

local Container = {}
Container.__index = Container

function Container.new()
	local self = setmetatable({}, Container)
	self._sandboxes = {}
	return table.freeze(self):withEnvironment(Environment.new()):withSandbox(Sandbox.new())
end

function Container:withEnvironment(environment: Environment)
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

function Container:withSandboxes(...: Sandbox)
	local clone = table.clone(self)

	-- Clone the sandboxes list & add the sandbox
	clone._sandboxes = table.clone(clone._sandboxes)
	for _, sandbox in ipairs({...}) do
		clone._sandboxes[sandbox] = if clone._environment then clone._environment:boundTo(sandbox) else false
	end

	-- Return the clone and freeze it
	return table.freeze(clone)
end

function Container:withoutSandboxes(...: Sandbox)
	local clone = table.clone(self)

	-- Clone the sandboxes list & remove the sandbox
	clone._sandboxes = table.clone(clone._sandboxes)
	for _, sandbox in ipairs({...}) do
		clone._sandboxes[sandbox] = nil
	end

	-- Return the clone and freeze it
	return table.freeze(clone)
end

type PackedList = {Sandbox} | {[number]: Sandbox, n: number}
function Container:replaceSandboxes(sandboxes: {[Sandbox]: Sandbox} | PackedList, newSandboxes: PackedList?)
	if not newSandboxes then
		-- Create intermediary tables
		newSandboxes = {}
		local oldSandboxes = {}

		-- For each sandbox, insert the key into the old sandboxes list, and the value into the new sandboxes list
		for sandbox, newSandbox in sandboxes do
			table.insert(oldSandboxes, sandbox)
			table.insert(newSandboxes, newSandbox)
		end

		-- Replace the old sandboxes with the new ones
		return self:replaceSandboxes(oldSandboxes, newSandboxes)
	end
	return self:withSandboxes(unpack(sandboxes, 1, sandboxes.n)):withoutSandboxes(unpack(newSandboxes, 1, newSandboxes.n))
end

function Container:withRules(...: SandboxRule)
	return self:withEnvironment(self._environment:withRules(...))
end
function Container:withoutRules(...: SandboxRule)
	return self:withEnvironment(self._environment:withoutRules(...))
end

function Container:Terminate()
	-- Terminate all sandboxes
	for sandbox, _boundEnv in pairs(self._sandboxes) do
		sandbox:Terminate()
	end
end

function Container:renew()
	-- Renew all sandboxes
	local newSandboxes = {}
	for sandbox, _boundEnv in pairs(self._sandboxes) do
		newSandboxes[sandbox] = sandbox:renew()
	end
	self:replaceSandboxes(newSandboxes)
end

function Container:Destroy()
	self:Terminate()
end

function Container:Spawn(sandbox: Sandbox, callback: (...any) -> ...any, ...: any): (boolean, string?)
	assert(self._sandboxes[sandbox], "Sandbox is not part of the container.")

	local environment = self._environment
	return sandbox:Spawn(environment:applyTo(callback), ...)
end

return Container