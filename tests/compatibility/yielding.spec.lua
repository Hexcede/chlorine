--# selene: allow(undefined_variable)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage.Packages

	local Chlorine = require(Packages.Chlorine)

	local Sandbox = Chlorine.Sandbox
	local Environment = Chlorine.Environment

	local sandbox = Sandbox.new()
	local environment = Environment.new():boundTo(sandbox):withFenv({task = task})

	local it = it;
	local expect = expect;

	describe("sandbox", function()
		local success = false
		it("should be able to run and yield", function()
			expect(sandbox:Spawn(environment:applyTo(function()
				task.wait(1)
				success = true
			end))).to.never.be.equal(false)
		end)
		task.wait(1)
		it("should run all the way through", function()
			expect(success).to.be.ok()
		end)
	end)
end