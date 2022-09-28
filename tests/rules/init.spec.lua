--# selene: allow(undefined_variable)

return function()
	describe("replace", function()
		local it = it;
		local expect = expect;

		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local Packages = ReplicatedStorage.Packages

		local Chlorine = require(Packages.Chlorine)

		local Sandbox = Chlorine.Sandbox
		local Environment = Chlorine.Environment

		local globals = {
			globalReplaceMe = {};
			globalReplaceMe2 = {};
			toReplaceWith = {};
		}

		local environment = Environment.new():withRules({
			Rule = "Replace";
			Queries = {{
				Mode = "ByReference";
				Search = globals.globalReplaceMe;
			}, {
				Mode = "ByReference";
				Search = globals.globalReplaceMe2;
			}};
			Replacement = globals.toReplaceWith
		}):withFenv(globals)

		local sandbox = Sandbox.new()

		it("should replace all queries", function()
			sandbox:Spawn(environment:boundTo(sandbox):applyTo(function()
				expect(globalReplaceMe).to.equal(toReplaceWith)
				expect(globalReplaceMe2).to.equal(toReplaceWith)
				expect(globalReplaceMe).to.equal(globalReplaceMe2)
			end))
		end)
	end)
end