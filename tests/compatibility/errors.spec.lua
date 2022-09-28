--# selene: allow(undefined_variable)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage.Packages

	local Chlorine = require(Packages.Chlorine)

	local Sandbox = Chlorine.Sandbox
	local Environment = Chlorine.Environment

	local sandbox = Sandbox.new()
	local environment = Environment.new():withFenv(getfenv()):boundTo(sandbox)

	describe("from sandbox", function()
		local it = it;
		local expect = expect;

		local errorMessage = "ABC123"
		local success, result = sandbox:Spawn(environment:applyTo(function()
			error(errorMessage)
		end))

		it("should be returned", function()
			expect(success).to.be.equal(false)
			expect(result).to.be.a("string")
		end)

		it("should contain the error message", function()
			expect(string.find(result, errorMessage)).to.be.ok()
		end)

		it("should originate from the script defining the body", function()
			expect(string.find(result, debug.info(1, "s"))).to.be.ok()
		end)
	end)
end