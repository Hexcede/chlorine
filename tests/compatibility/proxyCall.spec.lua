return function()
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local Packages = ReplicatedStorage.Packages

    local Chlorine = require(Packages.Chlorine)

    local Sandbox = Chlorine.Sandbox
    local Environment = Chlorine.Environment

    local sandbox = Sandbox.new()
    local environment = Environment.new()
        :withFenv(getfenv())
        :boundTo(sandbox)

    describe("proxied functions", function()
        local it = it
        local expect = expect

        local function test()
            local bindable = Instance.new("BindableFunction")
            bindable.OnInvoke = function()
                return function()
                    return "result"
                end
            end
            bindable.Name = "TestBindable"

            return bindable:Invoke()()
        end

        environment:applyTo(test)

        it("should execute without errors", function()
            expect(pcall(test)).to.be.equal(true)
        end)

        it("should produce a valid result", function()
            expect(test()).to.be.equal("result")
        end)
    end)
end