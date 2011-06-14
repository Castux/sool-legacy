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
	self.selectors = {}	-- Table of methods indexed by selectors
	
	-- Reference to context
	
	self.context = context
	
	-- Reference to parse tree
	
	self.node = node
	
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
			mem.klass = self
			
			if mem:validate() then
				self:add_member(mem)
			end
		end
	end
	
	-- 4. TODO: Add all methods
	
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
		
		self:add_method(setter)
		
		-- And getter method
		
		local getter = Method(mem.name,mem.type,void)
		getter.builtin = true
		getter.private = mem.private
		
		self:add_method(getter)
	end

end

function Class:add_method(meth)
	
	-- Selector collision: complain or overload
	
	local other = self.selectors[meth.sel]
	
	if other then
		
		-- If it was in the same class, complain
		
		if other.klass == self then
			self.context:adderror('method with selector ' .. meth.sel.sig .. ' was already defined in this class', node_pos(meth.node))
			self.context:addinfo('here:', node_pos(other.node))
			return
		
		-- If it was in a parent class, overload by putting it at the same place
		
		else
			for i,v in ipairs(self.methods) do
				if v == other then
				
					-- Check that the whole signature is the same (return type too)
					
					if other.sig ~= meth.sig then
						self.context:adderror('return type mismatch in method ' .. meth.sig, node_pos(meth.node))
						self.context:addinfo('that overloads ' .. other.sig, node_pos(other.node))
						return
					end
					
					-- And replace
					
					self.methods[i] = meth
					self.selectors[meth.sel] = meth
					return
				end				
			end
		end
	
	end
	
	meth.klass = self
	
	table.insert(self.methods,meth)
	self.selectors[meth.sel] = meth
	
end
