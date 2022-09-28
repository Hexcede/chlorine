--# selene: allow(undefined_variable)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage.Packages

	local Chlorine = require(Packages.Chlorine)

	local Sandbox = Chlorine.Sandbox
	local Environment = Chlorine.Environment

	local sandbox = Sandbox.new()
	local environment = Environment.new():boundTo(sandbox)

	local it = it;
	local expect = expect;

	describe("empty sandbox", function()
		local success = false
		it("should be able to run", function()
			expect(sandbox:Spawn(environment:applyTo(function()
				success = true
			end))).to.never.be.equal(false)
		end)
		it("should run all the way through", function()
			expect(success).to.be.ok()
		end)
	end)
end