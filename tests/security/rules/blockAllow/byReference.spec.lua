--# selene: allow(undefined_variable)

return function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Packages = ReplicatedStorage.Packages

	local Chlorine = require(Packages.Chlorine)

	local Sandbox = Chlorine.Sandbox
	local Environment = Chlorine.Environment

	local globals = {
		it = it;
		globalBlockMe = {};
		globalBlockMeDont = {};
	}

	local dontBlockMeRule = {
		Rule = "Allow";
		Queries = {{
			Mode = "ByReference";
			Search = globals.globalBlockMeDont;
		}};
	}

	local environment = Environment.new():withRules({
		Rule = "Block";
		Queries = {{
			Mode = "ByReference";
			Search = globals.globalBlockMe;
		}, {
			Mode = "ByReference";
			Search = globals.globalBlockMeDont;
		}};
		Order = 1;
	}, dontBlockMeRule, {
		Rule = "Allow";
		Queries = {{
			Mode = "ByReference";
			Search = globals.globalBlockMe;
		}};
		Order = 2;
	}):withFenv(globals)

	local sandbox = Sandbox.new()
	describe("with exceptions", function()
		local it = it;
		local expect = expect;

		sandbox:Spawn(environment:boundTo(sandbox):applyTo(function()
			it("should block the specified global by reference", function()
				expect(globalBlockMe).to.never.be.ok()
			end)

			it("should not block rules that aren't specified", function()
				expect(globalBlockMeDont).to.be.ok()
			end)
		end))
	end)

	describe("without exceptions", function()
		local it = it;
		local expect = expect;

		sandbox:Spawn(environment:boundTo(sandbox):applyTo(function()
			it("should block the global that had the exception", environment:withoutRules(dontBlockMeRule):applyTo(function()
				expect(globalBlockMeDont).to.never.be.ok()
			end))

			it("should not effect other contexts", function()
				expect(globalBlockMeDont).to.be.ok()
			end)
		end))
	end)
end