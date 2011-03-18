require 'class'
require 'types'

local intern = {}

--[[
A selector is a combination of a method name and its argument types,
used - as the name indicates - to select a method to execute when
receiving a message. Selectors are unique per class, but can be shared
between classes, and will need to be compared a lot, and are used for 
indexing, hence the usefulness of internizing them.
]]

Selector = class()

-- arg_type is a unique TType, potentially a TMulti, itself can be empty

function Selector:init(name,arg_type)
	
	self.name = name
	
	self.arg_type = arg_type or TMulti({})
	
	self.arg_sig = self.arg_type.sig
	
	self.sig = self.name .. ':' .. self.arg_sig
	
	-- internizing
	if intern[self.sig] then
		return intern[self.sig]
	else
		intern[self.sig] = self
		return self
	end
end
