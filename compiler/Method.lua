require 'class'

require 'Selector'

Method = class()

function Method:init(name,rtype,atype)
	
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
	
	-- Remember the class in which it was defined
	
	self.klass = klass
	
	-- Attributes
	
	self.private = false
	self.builtin = false
	
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
