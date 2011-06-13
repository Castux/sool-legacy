require 'class'

require 'Selector'

Method = class()

function Method:init(name,rtype,atype,builtin)
	
	-- The interface is made of three things:
	
	self.name = name or ''		-- Name
	self.rtype = rtype or nil	-- Return type (a type object)
	self.atype = atype or nil	-- Argument type (a type object)
	
	-- From this we derive a selector and a signature
	
	self.sel = nil
	self.sig = ''
	
	if name then
		self:update_selector()
		self:update_signature()
	end
	
	-- Attributes
	
	self.private = false
	self.builtin = builtin or false
	
	-- Content
	
	self.code = nil		-- If any (not built-in), this is the AST
	
	-- Reference to parse tree
	
	self.node = nil
	
	return self
end

function Method:update_selector()
	self.sel = Selector(self.name,self.atype)
end

function Method:update_signature()
	self.sig = self.rtype:signature() .. ':' .. self.sel.sig
end
