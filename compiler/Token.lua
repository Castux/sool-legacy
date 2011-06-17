require 'class'

Token = class()

function Token:init(kind,value,pos)
	
	self.kind = kind or ''		-- Name, ClassName, Symbol, Number, String, or complete keyword
	self.value = value or ''	-- String of original text
	self.pos = pos or nil		-- Reference to position
	
	return self
end

function Token:position()
	return self.pos
end
