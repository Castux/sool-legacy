require 'class'

require 'Type'

local intern = {}

--[[
A selector is a combination of a method name and its argument types,
used - as the name indicates - to select a method to execute when
receiving a message. Selectors are unique per class, but can be shared
between classes, and will need to be compared a lot, and are used for 
indexing, hence the usefulness of internizing them.
]]

Selector = class()

function Selector:init(name,atype)
	
	self.name = name
	
	self.atype = atype
	
	self.asig = self.atype:signature()
	
	self.sig = self.name .. ':' .. self.asig
	
	-- internizing
	if intern[self.sig] then
		return intern[self.sig]
	else
		intern[self.sig] = self
		return self
	end
end
