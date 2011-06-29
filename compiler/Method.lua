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
	
	self.klass = nil
	
	-- Attributes
	
	self.private = false
	self.builtin = false
	self.setter = false
	
	-- Content
	
	self.code = nil		-- If any (not built-in), this is the AST
	
	-- Context
	
	self.context = nil
	self.node = nil
	
	self.priv_node = nil
	self.ret_node = nil
	self.name_node = nil
	self.arg_node = nil
	
	return self
end

function Method:update_selector()
	self.sel = Selector(self.name,self.atype)
end

function Method:update_signature()
	self.sig = self.rtype:signature() .. ':' .. self.sel.sig
end

function Method:validate_interface(context,node)
	
	assert( node.rule.name == 'method definition' )
	
	self.context = context
	self.node = node
	
	-- Privacity
	
	self.priv_node = node.nodes[2]
	
	if not self.priv_node:isa(EmptyNode) then
		self.private = true
	end
	
	-- Return type
	
	self.ret_node = node.nodes[3]
	
	local rtypes = {}
	
	if not self.ret_node:isa(EmptyNode) then
		local nodes = self.ret_node:flatten_list()
		
		for i,v in ipairs(nodes) do
			local t = Type()
			if not t:validate(self.context,v) then
				return false
			else
				table.insert(rtypes,t)
			end
		end
	end
	
	self.rtype = Type(unpack(rtypes))
	
	-- Name
	
	self.name_node = node.nodes[4]
	
	if self.name_node.nodes[1].kind == 'Name' then
		
		self.name = self.name_node.nodes[1].value
		if not self.name_node.nodes[2]:isa(EmptyNode) then
			self.name = self.name .. '='
			self.setter = true
		end
		
	else
		
		self.name = self.name_node.nodes[2].value
		
		-- TODO: allow only some binops
	end
	
	-- Arguments (only types for now)
	
	self.arg_node = node.nodes[6]
	local atypes = {}
	
	if not self.arg_node:isa(EmptyNode) then
		
		local nodes = self.arg_node:flatten_list()
		for i,v in ipairs(nodes) do
			
			local t = Type()
			if not t:validate(self.context,v.nodes[1]) then
				return false
			else
				table.insert(atypes,t)
			end
			
		end
	
	end
	
	self.atype = Type(unpack(atypes))
	
	self:update_selector()
	self:update_signature()
	
	-- Now some validity checks
	
	if self.setter then
		
		local bad = false
		
		if #self.rtype.types ~= 0 then
			self.context:adderror('setter methods must not return any values', self.ret_node:position())
			bad = true
		end
		
		if #self.atype.types ~= 1 then
			self.context:adderror('setter methods must take exactly one argument', self.node:position(5,7))
			bad = true
		end
		
		if bad then
			self.context:addinfo('this one is declared ' .. self.sig)
			return false
		end
	end
	
	return true
end
