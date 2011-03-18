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

function Selector:init(name,arg_types)
	
	self.name = name
	
	self.arg_types = arg_types or {}
	
	local s = ""
	for i,typ in ipairs(self.arg_types) do
		s = s .. typ.sig .. (i < #self.arg_types and ',' or '')
	end
	
	self.arg_sig = s
	
	self.sig = self.name .. ':' .. self.arg_sig
	
	-- internizing
	if intern[self.sig] then
		return intern[self.sig]
	else
		intern[self.sig] = self
		return self
	end
end
