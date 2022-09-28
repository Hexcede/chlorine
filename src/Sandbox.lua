local Primitives = require(script.Parent.Primitives)
type primitive = Primitives.primitive

-- If we do not have a warn function, create one
if not warn then
	-- Try to get the ansicolors library
	local ansicolors = pcall(require, "ansicolors")
	function warn(...)
		print(if ansicolors then ansicolors("%{yellow}[W]") else "[WARNING]", ..., debug.traceback(2))
	end
end

-- Which status to consider dead
local DEAD_STATUSES = {
	running = true;
	normal = true;
	dead = true;
}

-- Utility to close a thread safely depending on context
local function closeThread(thread: thread)
	-- If we consider the thread dead, do nothing
	if DEAD_STATUSES[coroutine.status(thread)] then
		return
	end

	-- If we have the task library (Roblox-only)
	if task then
		-- Attempt to kill the thread via task.cancel
		local success = pcall(task.cancel, thread)

		-- If killing the thread succeeded, return
		if success then
			return
		end
	end

	-- Attempt to kill the thread via coroutine.close
	if not pcall(coroutine.close, thread) then
		warn("Failed to kill thread", thread)
	end
end

local fullyWeak = {__mode = "kv"; __metatable="The metatable is locked."}

-- Sandbox
local Sandbox = {}
Sandbox.__index = Sandbox
Sandbox.UnsafeContext = newproxy(false)

export type authorable = thread | table | userdata | (...any) -> ...any;


local dataAuthors: WithMeta<{[authorable]: Sandbox}, typeof(fullyWeak)> = setmetatable({}, fullyWeak)
local function setAuthor(data: authorable, owner: Sandbox | nil)
	dataAuthors[data] = owner
	return data
end
local function getAuthor(data): (Sandbox | typeof(Sandbox.UnsafeContext))?
	return dataAuthors[data]
end

local function checkOwner(value: authorable, sandbox: Sandbox)
	-- Ensure the owner of the value is the specified sandbox
	assert(rawequal(getAuthor(value), sandbox), "Ownership check failed.")
	return value
end
local function checkOwnOwner(sandbox: Sandbox)
	-- Check that the sandbox is its own owner
	-- If it isn't, it isn't a valid sandbox
	checkOwner(sandbox, sandbox)
end

Sandbox.getOwner = getAuthor

local function renewSandbox(sandbox: Sandbox)
	-- Set the sandbox's author to itself
	setAuthor(sandbox, sandbox)

	-- Have the sandbox claim its own claimed list
	setAuthor(sandbox._claimed, sandbox)
	table.insert(sandbox._claimed, sandbox._claimed)

	-- Return the sandbox & freeze it
	return table.freeze(sandbox)
end

function Sandbox.new()
	local self = setmetatable({}, Sandbox)

	-- Create a table for all values claimed by this sandbox
	self._claimed = setmetatable({}, fullyWeak)

	-- Set the parent thread
	self._parentThread = coroutine.running()

	-- Renew the sandbox (it is currently in an unusable state)
	return renewSandbox(self)
end

function Sandbox:Renew()
	if getAuthor(self._claimed) then
		error("The Sandbox could not be renewed. Its context is already claimed by another Sandbox.", 2)
		return
	end

	-- Shallow-clone the sandbox and renew the clone
	return renewSandbox(table.clone(self))
end

function Sandbox:Terminate(terminationError: string?)
	checkOwnOwner(self)

	warn("Terminate", debug.traceback(terminationError))

	-- For each value the sandbox has claimed
	for _, claimedValue in ipairs(checkOwner(self._claimed, self)) do
		if rawequal(getAuthor(claimedValue), self) then
			-- Remove the author
			setAuthor(claimedValue, nil)

			-- If the value is a thread or script connection, clean it up
			if type(claimedValue) == "thread" then
				-- Skip the parent thread
				if self._parentThread == claimedValue then
					continue
				end

				closeThread(claimedValue)
			elseif typeof(claimedValue) == "RBXScriptSignal" then
				claimedValue:Disconnect()
			end
		end
	end

	-- If a termination error is specified, throw it
	if terminationError then
		error(string.format("The sandbox was terminated: %s", terminationError), 2)
	end
end

function Sandbox:IsSafe(value: authorable)
	checkOwnOwner(self)

	-- If the running thread isn't safe, return false
	local runningThread = coroutine.running()
	if not rawequal(value, runningThread) then
		if not self:IsSafe(runningThread) then
			return false
		end
	else
		-- If the value is the parent thread, it must be safe
		if rawequal(value, self._parentThread) then
			return true
		end
	end

	-- If the value is a primitive, it's safe
	if Primitives.isPrimitive(value) then
		return true
	end

	-- If the owner isn't this sandbox, return false
	if Sandbox.getOwner(value) ~= self then
		return false
	end

	-- Indicate that the value is safe
	return true
end

function Sandbox:AssertSafe(value: authorable?)
	checkOwnOwner(self)

	-- Allow methods called through Environment -> Sandbox to pass
	local Environment = require(script.Parent.Environment)
	if Sandbox.isCaller(2) and Environment.isCaller(3) then
		return
	end

	if not self:IsSafe(value) then
		self:Terminate(if value == nil then "Running in an unsafe context." else "Value is from an unsafe context.")
	end
end

function Sandbox:Claim(value: authorable, _token)
	checkOwnOwner(self)

	-- Assert that we are running in a safe context
	self:AssertSafe()

	-- If the thread already has an owner, do not claim the thread
	if Sandbox.getOwner(value) then
		return false
	end

	-- Insert the item into the list of claimed values
	table.insert(checkOwner(self._claimed, self), value)

	-- Set the author
	setAuthor(value, self)
	return true
end

function Sandbox:Release(value: authorable)
	checkOwnOwner(self)

	-- Assert that we are running in a safe context
	self:AssertSafe()

	-- If the thread already has an owner, do not claim the thread
	if not rawequal(Sandbox.getOwner(value), self) then
		return false
	end

	-- Set the author
	setAuthor(value, nil)
	return true
end

function Sandbox:Owns(value: authorable)
	return rawequal(getAuthor(value), self)
end

function Sandbox:ApplyEnvironment(env: table)
	-- For all claimed functions & threads, apply the fenv
	for _, claimedValue in ipairs(self._claimed) do
		if type(claimedValue) == "function" then
			setfenv(claimedValue, env)
		elseif type(claimedValue) == "thread" then
			local root = debug.info(claimedValue, "f")
			if root then
				setfenv(root, env)
			end
		end
	end
end

function Sandbox:Spawn(callback: (...any) -> (), ...: any): (boolean, string?)
	checkOwnOwner(self)

	local sandboxThread = coroutine.create(xpcall)
	assert(self:Claim(sandboxThread), "Failed to claim thread.")
	return select(2, coroutine.resume(sandboxThread, callback, debug.traceback, ...))
end

function Sandbox:Destroy()
	checkOwnOwner(self)

	self:Terminate()
end

function Sandbox.isCaller(level: number)
	return debug.info(1, "s") == debug.info(level + 1, "s")
end

export type Sandbox = typeof(Sandbox.new())
return table.freeze(Sandbox)