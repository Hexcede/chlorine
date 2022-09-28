-- Welcome to metatable hell
--  We hope you __enjoy your stay!

local Reflection = {}

function Reflection.__index(self, index)
	return self[index]
end
function Reflection.__newindex(self, index, value)
	self[index] = value
end
function Reflection.__call(self, ...)
	return self(...)
end
function Reflection.__concat(self, value)
	return self .. value
end
function Reflection.__unm(self)
	return -self
end
function Reflection.__add(self, other)
	return self + other
end
function Reflection.__sub(self, other)
	return self - other
end
function Reflection.__mul(self, other)
	return self * other
end
function Reflection.__div(self, other)
	return self / other
end
function Reflection.__mod(self, other)
	return self % other
end
function Reflection.__pow(self, other)
	return self ^ other
end
function Reflection.__tostring(self)
	return tostring(self)
end
function Reflection.__eq(self, other)
	return self == other
end
function Reflection.__lt(self, other)
	return self < other
end
function Reflection.__le(self, other)
	return self <= other
end
function Reflection.__len(self)
	return #self
end
function Reflection.__iter(self)
	return coroutine.wrap(function(_object)
		for first, second, third, fourth in self do
			if not rawequal(first, nil) then
				coroutine.yield(first, second, third, fourth)
			end
		end
	end), self
end

function Reflection:wrap(proxyMetamethod: (...any) -> ...any)
	local ProxyReflection = {}
	function ProxyReflection.__index(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__newindex(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__call(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__concat(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__unm(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__add(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__sub(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__mul(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__div(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__mod(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__pow(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__tostring(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__eq(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__lt(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__le(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__len(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	function ProxyReflection.__iter(proxy, ...)
		return proxyMetamethod(proxy, ...)
	end
	return table.freeze(ProxyReflection)
end

return table.freeze(Reflection)