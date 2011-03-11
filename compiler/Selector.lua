require 'class'
require 'types'

local intern = {}

Selector = class()

function Selector:init(name,arg_types)
	
	self.name = name
	
	self.arg_types = arg_types or {}
	
	local s = ""
	for _,typ in ipairs(self.arg_types) do
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
