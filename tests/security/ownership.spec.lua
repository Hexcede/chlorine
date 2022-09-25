--# selene: allow(undefined_variable)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage.Packages

	local Chlorine = require(Packages.Chlorine)

	local Sandbox = Chlorine.Sandbox
	local Environment = Chlorine.Environment

	local sandbox = Sandbox.new()
	local environment = Environment.new():withFenv({}):boundTo(sandbox)

	local it = it;
	local expect = expect;

	describe("sandbox", function()
		it("should be safe to use", function()
			expect(sandbox:IsSafe()).to.be.equal(true)
		end)

		it("should not be safe to use in another thread", function()
			coroutine.wrap(function()
				expect(sandbox:IsSafe()).to.never.be.equal(true)
			end)()
		end)

		it("should own itself", function()
			expect(Sandbox.getOwner(sandbox)).to.be.equal(sandbox)
		end)

		it("should not own this thread", function()
			expect(Sandbox.getOwner(coroutine.running())).to.never.be.equal(sandbox)
		end)
	end)
end