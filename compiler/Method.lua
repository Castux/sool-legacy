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
	
	if #node[2] > 0 then
		self.private = true
	end
	
	-- Return type
	
	local rtypes = {}
	
	if #node[3] > 0 then
		local nodes = nova.flatten_list(node[3][1])
		
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
	
	local nnode = node[4]
	
	if nnode[1][1][1] == 'Name' then
		
		self.name = nnode[1][1][2]
		if #nnode[2] > 0 then
			self.name = self.name .. '='
			self.setter = true
		end
		
	elseif nnode[1][1][1] == 'op' then
		
		self.name = nnode[2][1][1]
		
		-- TODO: allow only some binops
	end
	
	-- Arguments (only types for now)
	
	local atypes = {}
	
	if #node[6] > 0 then
		
		local nodes = nova.flatten_list(node[6][1])
		for i,v in ipairs(nodes) do
			
			local t = Type()
			if not t:validate(self.context,v[1][1]) then
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
			self.context:adderror('setter methods must not return any values', nova.node_pos(node[3]))
			bad = true
		end
		
		if #self.atype.types ~= 1 then
			self.context:adderror('setter methods must take exactly one argument', nova.node_pos(node[6]))
			bad = true
		end
		
		if bad then
			self.context:addinfo('this one is declared ' .. self.sig)
			return false
		end
	end
	
	return true
end
