local Primitives = require(script.Parent.Primitives)
local Reflection = require(script.Parent.Reflection)
local Sandbox = require(script.Parent.Sandbox)
local Rules = require(script.Parent.Rules)

local Caller = require(script.Parent.Caller)
function Caller.Environment.isCaller(level: number)
	return debug.info(1, "s") == debug.info(level + 1, "s")
end
table.freeze(Caller.Environment)

type Sandbox = Sandbox.Sandbox
type Rules = Rules.Rules
type Rule = Rules.Rule
type RuleResult = Rules.RuleResult

export type RuleCallback = (environment: Environment, match: RuleResult) -> RuleResult?

export type CustomRule = Rule & { Rule: RuleCallback; }
export type AllowRule = Rule & { Rule: "Allow"; }
export type BlockRule = Rule & { Rule: "Block"; }
export type TerminateRule = Rule & { Rule: "Terminate"; }
export type ReplaceRule = Rule & { Rule: "Replace"; Replacement: any?; }
export type SandboxRule = CustomRule | AllowRule | BlockRule | TerminateRule | ReplaceRule

-- Proxy data symbol
local PROXY_DATA = newproxy(false)

local Environment = {}
Environment.__index = Environment

Environment.rules = table.freeze({
	Allow = function(_environment: Environment, _result: RuleResult) end;
	Block = function(_environment: Environment, result: RuleResult)
		return result:withValue(nil)
	end;
	Terminate = function(environment: Environment, result: RuleResult)
		local sandbox = environment:GetSandbox()
		if sandbox then
			sandbox:Terminate("Terminate by rule.")
		end
		error("Terminate by rule.")
		return result:withValue(nil)
	end;
	Replace = function(_environment: Environment, result: RuleResult)
		local rule = result.rule :: ReplaceRule
		return result:withValue(rule.Replacement)
	end;
});

local function addProxy(environment)
	local sandbox = environment:GetSandbox()
	if sandbox then
		sandbox:Claim(environment)
	end

	local toProxyOld = environment._toProxy
	local toTargetOld = environment._toTarget

	environment._toProxy = setmetatable({}, {__mode="k"; __metatable="The metatable is locked."})
	environment._toTarget = setmetatable({}, {__mode="v"; __metatable="The metatable is locked."})

	-- For all previously proxied values, re-wrap them
	if toProxyOld then
		for target, proxy in toProxyOld do
			-- If the proxy is the key, continue
			if rawequal(target, proxy) then
				continue
			end

			-- Grab the proxy data
			local data = assert(rawget(proxy, PROXY_DATA), "Invalid proxy object.")

			-- Re-proxy the target
			environment:wrap(data._target, data._inputMode)
		end
	end

	if toTargetOld then
		-- If there exists a wrapped environment for the sandbox
		local env = environment._env
		local target = env and toTargetOld[env]
		if target then
			-- Replace the wrapped environment
			environment._env = environment:wrap(target)
		end
	end

	return environment
end

local function _clone(environment: Environment, copyOwner: boolean?)
	local copy = table.clone(environment)
	if copyOwner == false then
		copy._sandbox = nil
	end
	return addProxy(copy)
end
function Environment.new()
	local self = setmetatable({}, Environment)
	self._rules = Rules.new()
	self._env = {}
	return table.freeze(addProxy(self))
end

function Environment:clone(copyOwner: boolean?)
	return table.freeze(_clone(self, copyOwner))
end

function Environment:boundTo(sandbox: Sandbox)
	local newEnvironment = _clone(self, false)
	newEnvironment._sandbox = sandbox
	sandbox:Claim(newEnvironment)
	return table.freeze(newEnvironment)
end

function Environment:applyTo(functionToBind: (...any) -> ...any): (...any) -> ...any
	return assert(setfenv(functionToBind, (assert(self._env, "Environment is not initialized. Call Environment:withFenv(globals) to initialize it."))))
end

export type proxyable = {[any]: any} | (...any) -> ...any

-- Wraps all values in the list into proxies
local function wrapList(environment: Environment, list: {n: number, [number]: any}, inputMode: ("forLua" | "forBuiltin")?)
	list.n = list.n or #list
	for i=1, list.n do
		list[i] = environment:wrap(list[i], inputMode)
	end
end
-- Unwraps all values in the list into their proxy targets
local function unwrapList(environment: Environment, list: {n: number, [number]: any})
	list.n = list.n or #list
	for i=1, list.n do
		list[i] = environment:unwrap(list[i])
	end
end

-- Calls a function and transforms its inputs as specified by inputMode, and its outputs into proxies
local function callFunctionTransformed(self: Environment, inputMode: "forLua" | "forBuiltin", target: (...any) -> (...any), ...: any)
	-- Pack arguments
	local args = table.pack(...)

	-- Look for a sandbox
	local sandbox = self:GetSandbox()
	local thread = coroutine.running()

	-- Convert all input arguments either to their wrapped values, or their targets depending on the input mode
	if inputMode == "forLua" then
		wrapList(self, args, inputMode)
	elseif inputMode == "forBuiltin" then
		unwrapList(self, args)
	else
		error(string.format("Invalid inputMode %s", inputMode), 2)
	end

	-- CPU timer (pre-call)
	if sandbox then
		-- Start the CPU timer for this thread if entering lua code or unyieldable code, otherwise, stop the timer
		if inputMode == "forLua" or not coroutine.isyieldable() then
			sandbox:StartTimer(thread)
		else
			sandbox:StopTimer(thread)
		end
	end

	-- Call the target and collect all results
	local results = table.pack(xpcall(target, debug.traceback, table.unpack(args, 1, args.n)))

	-- CPU timer (post-call)
	if sandbox then
		-- Stop the CPU timer for this thread if exiting lua code, otherwise, start the timer again, we're re-entering sandboxed code
		if inputMode == "forLua" then
			sandbox:StopTimer(thread)
		else
			sandbox:StartTimer(thread)
		end
	end

	-- If the call failed, bubble the error
	local success, result = table.unpack(results, 1, 2)
	assert(success, result)

	-- Convert all outputs to wrapped values
	wrapList(self, results)

	-- Unpack results
	return table.unpack(results, 2, results.n)
end

-- Calls a metamethod by name for the given proxy and arguments
local function proxyMetamethod(proxy: any, ...: any)
	-- Grab the name of the current metamethod (Name of the caller)
	local metamethod = debug.info(2, "n")

	-- Ensure that the object being acted on is a proxy and grab the proxy data from it
	local data = assert(rawget(proxy, PROXY_DATA), string.format("Invalid proxy invoked metamethod proxy.%s (%s)", metamethod, type(proxy)))

	-- Determine the input mode to use for the call
	-- When using __call, we want to use the proxy's input mode
	local inputMode = if metamethod == "__call" then data._inputMode else "forBuiltin"

	-- Grab the proxy's associated environment and target
	local environment = data._environment
	local target = data._target

	-- Ensure that the environment and target exist
	assert(environment and target, "The object isn't a valid Proxy.")

	-- Look for a sandbox
	local sandbox = environment:GetSandbox()
	if sandbox then
		-- Try to claim the running thread
		sandbox:Claim(coroutine.running())
	end

	-- If the metamethod is __call, don't use Reflection or there'll be infinite recursion in forLua mode due to argument wrapping
	if metamethod == "__call" then
		return callFunctionTransformed(environment, inputMode, target, ...)
	end

	-- Call the metamethod
	return callFunctionTransformed(environment, inputMode, Reflection[metamethod], target, ...)
end

-- Create reflection for proxies
local ProxyReflection = Reflection:wrap(proxyMetamethod)

-- Creates a proxy targeting a particular value
function Environment:wrap(target: proxyable, inputMode: ("forLua" | "forBuiltin")?): proxyable
	-- Test env rules
	local ruleResult = self:test(target)
	if ruleResult then
		target = ruleResult.value
	end

	-- Check if the target is a primitive
	if Primitives.isPrimitive(target) or type(target) == "thread" then
		return target
	end

	-- Check if the target is already proxied
	if self._toProxy[target] then
		return self._toProxy[target]
	end

	-- If the target is a function, use forBultin if its a CFunction
	if not inputMode and type(target) == "function" then
		inputMode = if debug.info(target, "s") == "[C]" then "forBuiltin" else inputMode
	end

	-- If the inputMode is default, use forLua
	if not inputMode then
		inputMode = "forLua"
	end

	-- Check that the input mode for functions is valid
	assert(inputMode == "forLua" or inputMode == "forBuiltin", string.format("Invalid input mode for wrapping: %s", tostring(inputMode)))

	-- Create and freeze proxy
	local proxy = table.freeze(setmetatable({
		[PROXY_DATA] = table.freeze({
			_inputMode = inputMode;
			_target = target;
			_environment = self;
		})
	}, ProxyReflection))

	-- Grab the associated sandbox, if any
	local sandbox = self:GetSandbox()
	if sandbox then
		-- Attempt to claim the current environment
		sandbox:Claim(self)

		-- Try to claim the proxy
		sandbox:Claim(proxy)

		-- If the target is an RBXScriptConnection, try to claim it
		if typeof(target) == "RBXScriptConnection" then
			sandbox:Claim(target)
		end
	end

	-- Map the target to the proxy and the proxy to the target
	self._toProxy[target] = proxy
	self._toTarget[proxy] = target

	-- Map proxy/target to themselves in correct context
	self._toProxy[proxy] = proxy
	self._toTarget[target] = target

	return proxy
end

function Environment:unwrap(target: proxyable)
	-- Check if the target is a primitive
	if Primitives.isPrimitive(target) or type(target) == "thread" then
		return target
	end
	return self._toTarget[target] or target
end

function Environment:withFenv<K, V>(globals: {[K]: V})
	local newEnvironment = _clone(self)
	newEnvironment._env = newEnvironment:wrap(globals)
	return table.freeze(newEnvironment)
end

function Environment:withRules(...: SandboxRule)
	local newEnvironment = _clone(self)
	newEnvironment._rules = newEnvironment._rules:with(...)
	return table.freeze(newEnvironment)
end

function Environment:withoutRules(...: SandboxRule)
	local newEnvironment = _clone(self)
	newEnvironment._rules = newEnvironment._rules:without(...)
	return table.freeze(newEnvironment)
end

function Environment:_applyMatch(result: RuleResult): RuleResult
	local rule = result.rule

	-- Determine what function to call to activate the rule, and return the result
	local ruleMode = rule.Rule
	local ruleFn = if type(ruleMode) == "function" then ruleMode else assert(Environment.rules[ruleMode], string.format("Invalid rule kind %s", ruleMode))
	assert(type(ruleFn) == "function", "Invalid rule function.")

	-- Call the rule function
	local replacementResult = ruleFn(self, result)

	-- If a replacement result was specified, return that one instead of the default
	if replacementResult then
		return replacementResult
	end
	return result
end

function Environment:GetSandbox(): Sandbox?
	return self._sandbox
end

function Environment:test(value: any, sortComparator: Rules.RuleComparator?): RuleResult?
	-- Allow all primitives and threads to always pass
	if Primitives.isPrimitive(value) or type(value) == "thread" then
		return
	end

	-- Test all rules on the value
	local ruleResult = self._rules:test(value, sortComparator)

	-- If a rule matched, apply it
	if ruleResult then
		ruleResult = self:_applyMatch(ruleResult)
	end

	-- Return the rule result
	return ruleResult
end

export type Environment = typeof(Environment.new())
return table.freeze(Environment)