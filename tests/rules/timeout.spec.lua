--# selene: allow(undefined_variable)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage.Packages

	local Chlorine = require(Packages.Chlorine)

	local Sandbox = Chlorine.Sandbox
	local Environment = Chlorine.Environment

	local sandbox = Sandbox.new()
	local environment = Environment.new():boundTo(sandbox):withFenv({coroutine = coroutine; task = task; print = print;})

	local it = it;
	local expect = expect;

	describe("sandbox", function()
		it("should not be able to exceed the timeout", function()
			sandbox:SetTimeout(0.1)
			expect(sandbox:Spawn(environment:applyTo(function()
				while true do
					coroutine.running()
				end
			end))).to.be.equal(false)
		end)
		it("should work if there are other threads", function()
			sandbox = sandbox:renew()
			environment = environment:boundTo(sandbox)

			sandbox:SetTimeout(0.1)
			expect(sandbox:Spawn(environment:applyTo(function()
				while true do
					task.wait()
				end
			end))).to.never.be.equal(false)
			expect(sandbox:Spawn(environment:applyTo(function()
				assert(coroutine.resume(coroutine.create(function()
					while true do
						function doWait()
							task.wait()
						end
						task.spawn(doWait)
						task.spawn(task.wait)
					end
				end)))
			end))).to.be.equal(false)
		end)
	end)
end