export type primitive = number | string | boolean;
local PRIMITIVE_TYPES = table.freeze({
	["number"] = true;
	["string"] = true;
	["boolean"] = true;
	["nil"] = true;
	["vector"] = true;
})

local Primitives = {}
Primitives.PRIMITIVE_TYPES = PRIMITIVE_TYPES

function Primitives.isPrimitive(value: any): boolean
	return PRIMITIVE_TYPES[type(value)] or false
end

return table.freeze(Primitives)