--# selene: allow(undefined_variable)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage.Packages

	local Chlorine = require(Packages.Chlorine)

	local Sandbox = Chlorine.Sandbox
	local Environment = Chlorine.Environment

	local globals = {
		globalSuccess = true
	}

	local sandbox = Sandbox.new()
	local environment = Environment.new():withFenv(globals):boundTo(sandbox)

	local it = it;
	local expect = expect;

	describe("sandbox with globals", function()
		it("should run to completion", function()
			expect(sandbox:Spawn(environment:applyTo(function()
				it("should be able to get globals", function()
					expect(globalSuccess).to.be.ok()
				end)
			end))).to.never.be.equal(false)
		end)
	end)
end