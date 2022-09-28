local Queries = require(script.Parent.Queries)
type Query = Queries.Query

-- RuleResult
local RuleResult = {}
RuleResult.__index = RuleResult

-- The result of a match from Rules:test()
export type RuleResult = WithMeta<{rule: Rule, query: Query, value: any?}, typeof(RuleResult)>

function RuleResult.new(rule: Rule, query: Query, value: any?): RuleResult
	local result = setmetatable({
		rule = rule;
		query = query;
		value = value;
	}, RuleResult)
	return table.freeze(result)
end

function RuleResult:withValue(value: any?)
	local newResult = table.clone(self)
	newResult.value = value
	return table.freeze(newResult)
end

-- A rule to attempt to match
export type Rule = {
	Rule: string | (...any) -> ...any;
	Queries: {Query};
	Order: number?;
	[any]: any;
};

-- A comparator to use for sorting rules
export type RuleComparator = ((ruleA: Rule, ruleB: Rule) -> boolean);

local Rules = {}
Rules.__index = Rules

-- Create a set of empty rules to copy from
local EMPTY_RULES = setmetatable({n = 0, _ruleMap = table.freeze({})}, Rules)

function Rules.new(...: Rule)
	-- Create an empty set of rules and freeze it
	local rules = table.freeze(table.clone(EMPTY_RULES))

	-- If any argument is passed, return a set of rules with the inputs
	if select("#", ...) > 0 then
		return rules:with(...)
	end
	return rules
end

function Rules:with(...: Rule)
	local newRules = table.clone(self)

	-- Collect list of rules
	local ruleList = {...}

	-- Create a map of rules to their cloned representations, so we can prevent external mutations to the entire tree of rules
	local ruleMap = table.clone(newRules._ruleMap)
	newRules._ruleMap = ruleMap

	-- Freeze all queries
	for index, rule in ipairs(ruleList) do
		-- Clone the rule
		local ruleClone = table.clone(rule)

		-- Map the original to the clone
		ruleMap[rule] = ruleClone

		-- Freeze rule queries
		ruleClone.Queries = table.freeze(table.clone(ruleClone.Queries))

		-- Replace the rule in the rule list with the clone, and freeze it
		ruleList[index] = table.freeze(ruleClone)
	end

	-- Freeze the rule map
	table.freeze(ruleMap)

	-- Count all the new rules to add
	local count = select("#", ...)

	-- Copy the new rules into our clone & increment the stored length
	table.move(ruleList, 1, count, newRules.n + 1, newRules)
	newRules.n += count

	-- Freeze our new set of rules
	return table.freeze(newRules)
end

function Rules:without(...: Rule)
	-- Create a map of rules to ignore
	local rulesToIgnore = {...}
	for _index, rule in ipairs(rulesToIgnore) do
		-- Map the rule to its clone, and skip if it doesn't have one (isn't part of this rules set)
		rule = self._ruleMap[rule]
		if not rule then
			continue
		end

		-- Add the rule to the ignore map
		rulesToIgnore[rule] = true
	end

	-- Create a new empty set of rules
	local newRules = table.clone(EMPTY_RULES)

	-- Add all of the rules from this set, but ignore the input rules
	for _, rule in ipairs(self) do
		-- Skip any ignored rules
		if rulesToIgnore[rule] then
			continue
		end

		-- Increment the length of the rules set & insert the rule
		newRules.n += 1
		newRules[newRules.n] = rule
	end

	-- Freeze the result
	return table.freeze(newRules)
end

function Rules:sort(comparator: RuleComparator?)
	-- Create a copy of these rules
	local newRules = table.clone(self)

	-- Sort them by their orders
	table.sort(newRules, comparator or function(ruleA, ruleB)
		local orderA = ruleA.Order or 0
		local orderB = ruleB.Order or 0

		-- Otherwise, use less than
		return orderA < orderB
	end)

	-- Freeze the result
	return table.freeze(newRules)
end

function Rules:deduplicate()
	-- Create a table to hold all of the duplicates we want to ignore
	local rulesToIgnore = {}

	-- Create a new empty set of rules
	local newRules = table.clone(EMPTY_RULES)

	-- Add all of the rules from this set, but ignore duplicates
	for _, rule in ipairs(self) do
		-- Skip any ignored rules
		if rulesToIgnore[rule] then
			continue
		end

		-- Mark that we want to ignore this rule in the future
		rulesToIgnore[rule] = true

		-- Increment the length of the rules set & insert the rule
		newRules.n += 1
		newRules[newRules.n] = rule
	end

	-- Freeze the result
	return table.freeze(newRules)
end

function Rules:test(value: any, sortComparator: RuleComparator?): RuleResult?
	-- Sort the rules
	local sorted = self:sort(sortComparator)

	-- Keep track of the final result
	local result: Queries.QueryResult = { matched = false; }

	-- Keep track of the Rule & Query we matched, if any
	local matchedRule: Rule?
	local matchedQuery: Query?

	-- Try each rule
	for _, rule: Rule in ipairs(sorted) do
		for _, query in ipairs(rule.Queries) do
			result = Queries.test(query, value)

			-- If there is no match, continue to the next query
			if not result then
				continue
			end

			-- If there is a replacement, update the value we are testing
			if not rawequal(result.replacement, Queries.NoReplacement) then
				value = result.replacement
			end

			-- If we matched, stop testing
			if result.matched then
				matchedQuery = query;
				break
			end
		end
		-- If we matched, stop testing
		if result.matched then
			matchedRule = rule;
			break
		end
	end

	-- Determine the result
	return if result.matched then RuleResult.new(matchedRule, matchedQuery, value) else nil
end

export type Rules = WithMeta<{Rule}, typeof(Rules)>
return table.freeze(Rules)