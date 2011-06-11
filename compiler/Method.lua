require 'class'

Method = class()

function Method:init()
	
	-- The interface is made of three things:
	
	self.name = ''		-- Name
	self.rtype = nil	-- Return type (a type object, may be multi)
	self.atype = nil	-- Argument type (a type object, may be multi)
	
	-- From this we derive a selector and a signature
	
	self.sel = nil
	self.sig = ''
	
	-- Attributes
	
	self.private = false
	self.builtin = false
	
	-- Content
	
	self.code = nil		-- If any (not built-in), this is the AST
	
	-- Reference to parse tree
	
	self.node = nil
	
	return self
end
