--# selene: allow(undefined_variable)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage.Packages

	local Chlorine = require(Packages.Chlorine)

	local Sandbox = Chlorine.Sandbox
	local Environment = Chlorine.Environment

	function void() end

	local sandbox = Sandbox.new()
	local environment = Environment.new():withFenv({coroutine = coroutine; void = void; assert = assert}):boundTo(sandbox)

	-- Import void as a builtin
	environment:wrap(void, "forBuiltin")

	local it = it;
	local expect = expect;

	describe("sandbox", function()
		it("should be safe to use", function()
			expect(sandbox:IsSafe()).to.be.equal(true)
		end)

		it("should not be safe to use in another thread", function()
			local safe
			coroutine.wrap(function()
				safe = sandbox:IsSafe()
			end)()
			expect(safe).to.be.equal(false)
		end)

		it("should be safe to use in a child thread", function()
			local safe
			sandbox:Spawn(environment:applyTo(function()
				void()
				safe = sandbox:IsSafe()
			end))
			expect(safe).to.be.equal(true)
		end)

		it("should be safe to use in any descendant thread", function()
			local safe1, safe2
			assert(sandbox:Spawn(environment:applyTo(function()
				safe1 = sandbox:IsSafe()
				coroutine.wrap(function()
					void()
					safe2 = sandbox:IsSafe()
				end)()
			end)))
			expect(safe1).to.be.equal(true)
			expect(safe2).to.be.equal(true)
		end)

		it("should own itself", function()
			expect(Sandbox.getOwner(sandbox)).to.be.equal(sandbox)
		end)

		it("should not own parent thread", function()
			expect(Sandbox.getOwner(coroutine.running())).to.never.be.equal(sandbox)
		end)

		it("should not own any associated ancestor thread", function()
			local otherThread = coroutine.create(void)
			local doesOwn
			assert(sandbox:Spawn(environment:applyTo(function()
				abc = otherThread
				coroutine.resume(otherThread)

				doesOwn = Sandbox:Owns(otherThread)
			end)))
			expect(doesOwn).to.be.equal(false)
		end)
	end)
end