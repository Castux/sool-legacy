require 'class'

require 'Member'
require 'Method'

Class = class()

function Class:init(context,node)
	
	-- Interface
	
	self.name = ''		-- Class name
	self.parent = nil	-- Class parent
	
	self.members = {}	-- List of member objects, including inherited ones
						-- (also indexed by member names)
	
	self.methods = {}	-- List of method objects, including inherited ones
						-- (also indexed by selectors)
	
	-- Reference to context
	
	self.context = context
	
	-- Reference to parse tree
	
	self.node = node
	
	-- Basic info gathering
	
	self.name_node = node.nodes[2]
	self.name = self.name_node.value
	
	if not node.nodes[3]:isa(EmptyNode) then
		self.parent_node = node.nodes[3].nodes[2]
	end
	
	-- Memoization
	
	self.valid_interface = false
	
	return self
end

function Class:validate_interface()
	
	if self.valid_interface then
		return
	end
	
	-- 1. Make sure parent is already valid
	
	if self.parent then
		self.parent:validate_interface()
	end
	
	-- 2. Inherit from parent
	
	if self.parent then
		
		-- Members
		
		for i,mem in ipairs(self.parent.members) do
			table.insert(self.members,mem)
			self.members[mem.name] = mem
		end
		
		-- Methods

		for i,meth in ipairs(self.parent.methods) do
			table.insert(self.methods,meth)
			self.methods[meth.sel] = meth
		end

		
	end
	
	-- 3. Add all members
	
	local mem_met_node = self.node[4]
	
	for i,n in ipairs(mem_met_node) do
		if n.rule.name == 'member definition' then
			
			local mem = Member(self.context,n)
			
			if mem:validate() then
				self:add_member(mem)
			end
		end
	end
	
	-- 4. Add all methods

	for i,n in ipairs(mem_met_node) do
		if n.rule.name == 'method definition' then
			
			local meth = Method()
			
			if meth:validate_interface(self.context,n) then
				self:add_method(meth)
			end
		end
	end
	
	-- DEBUG
	
	print(self.name)
	for i,v in ipairs(self.members) do
		print('',v.type:signature(),v.name)
	end

	for i,v in ipairs(self.methods) do
		print('',v.sig)
	end
	
	
	-- Memo
	
	self.valid_interface = true
end

function Class:add_member(mem)
	
	mem.klass = self
	
	-- Check name collision
	
	local other = self.members[mem.name]
	if other then
		self.context:adderror('member ' .. mem.name .. ' was already defined', mem.node[3][1][1][3])
		
		if other.klass == self then
			self.context:addinfo('here:',other.node[3][1][1][3])
		else
			self.context:addinfo('in parent class ' .. other.klass.name .. ':', other.node[3][1][1][3])
		end
	else
		-- Add to members table
		
		table.insert(self.members,mem)
		self.members[mem.name] = mem
		
		-- Add automatic setter methods
		
		local void = Type()
		
		local setter = Method(mem.name .. '=',void,mem.type)
		setter.builtin = true
		setter.private = mem.private
		setter.setter = true
		
		self:add_method(setter)
		
		-- And getter method
		
		local getter = Method(mem.name,mem.type,void)
		getter.builtin = true
		getter.private = mem.private
		
		self:add_method(getter)
	end

end

function Class:add_method(meth)
	
	-- Basic forbidden method/member name collision
	
	if self.members[meth.name] then
		self.context:adderror('method definition shadows member of the same name', nova.node_pos(meth.node))
		self.context:addinfo('defined here:', nova.node_pos(self.members[meth.name].node))
		return false
	end
		
	-- Selector collision: complain or overload
	
	local other = self.methods[meth.sel]
	
	if other then
		
		-- If it was in the same class, complain
		
		if other.klass == self then
			self.context:adderror('method with selector ' .. meth.sel.sig .. ' was already defined in this class', nova.node_pos(meth.node))
			self.context:addinfo('here:', nova.node_pos(other.node))
			return false
		
		-- If it was in a parent class, overload by putting it at the same place
		
		else
			for i,v in ipairs(self.methods) do
				if v == other then
				
					-- Check that the whole signature is the same (return type too)
					
					if other.sig ~= meth.sig then
						self.context:adderror('return type mismatch in method ' .. meth.sig, nova.node_pos(meth.node))
						self.context:addinfo('that overrides ' .. other.sig, nova.node_pos(other.node))
						return false
					end
					
					-- And replace
					
					self.methods[i] = meth
					self.selectors[meth.sel] = meth
					return false
				end				
			end
		end
	
	end
	
	print('adding ', meth.sig, other)
	
	meth.klass = self
	
	table.insert(self.methods,meth)
	self.methods[meth.sel] = meth
	
end
