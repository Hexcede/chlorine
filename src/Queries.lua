-- Kinds of queries for rules
export type ByReference = {
	Mode: "ByReference";
	Search: any;
}
export type ByTypeOf = {
	Mode: "ByTypeOf";
	Search: typeof(typeof(nil :: any));
}
export type ByComposition = {
	Mode: "ClassEquals" | "IsA";
	Search: string;
}
export type ByAncestry = {
	Mode: "IsDescendantOf" | "IsAncestorOf";
	Search: Instance;
	Inclusive: boolean?;
}
export type Custom = (value: any) -> (boolean?, any?)
export type Query = ByReference | ByTypeOf | ByComposition | ByAncestry | Custom;

local Queries = {}
Queries.NoReplacement = newproxy(false)

export type QueryResult = {
	matched: boolean; -- If this is true, we've found a match
	replacement: any?; -- Will be Queries.NoReplacement if there is no replacement
}

Queries.all = table.freeze({
	ByReference = function(query: ByReference, value: any)
		return rawequal(query.Search, value)
	end;
	ByTypeOf = function(query: ByTypeOf, value: any)
		return rawequal(query.Search, typeof(value))
	end;
	ByComposition = function(query: ByComposition, value: Instance)
		assert(typeof(value) == "Instance", "Invalid ByComposition query, value is not an Instance.")
		if query.Mode == "ClassEquals" then	
			return query.Search == value.ClassName
		elseif query.Mode == "IsA" then
			return value:IsA(query.Search)
		end
		error(string.format("Invalid ByComposition.Mode %s", query.Mode), 2)
	end;
	ByAncestry = function(query: ByAncestry, value: Instance)
		assert(typeof(value) == "Instance", "Invalid ByAncestry query, value is not an Instance.")
		-- If the query is inclusive and the two instances match, return true
		if query.Inclusive and rawequal(query.Search, value) then
			return true
		end

		if query.Mode == "IsDescendantOf" then
			return query.Search:IsAncestorOf(value)
		elseif query.Mode == "IsAncestorOf" then
			return query.Search:IsDescendantOf(value)
		end
		error(string.format("Invalid ByAncestry.Mode %s", query.Mode), 2)
	end;
})

function Queries.test(query: Query, value: any): QueryResult
	local queryFn = if type(query) == "function" then query else assert(Queries.all[query.Mode], string.format("Invalid Query mode %s", query.Mode))
	assert(type(queryFn) == "function", "Invalid query function.")

	local results = table.pack(queryFn(query, value))
	-- Determine if a replacement was specified
	local shouldReplace = results.n > 1

	-- Return the match & replacement
	return {
		-- Convert first result into a boolean for whether or not we matched
		matched = not not results[1];
		-- Determine the value to replace, if any, otherwise specify that there is no replacement
		replacement = if shouldReplace then results[2] else Queries.NoReplacement;
	}
end

return table.freeze(Queries)