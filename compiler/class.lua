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
		
		-- TODO: Methods
		
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
		setter.builtin = true
		setter.private = mem.private
		
		self:add_method(getter)
	end

end

function Class:add_method(meth)
	
	-- TODO: selector collision
	
	table.insert(self.methods,meth)
	self.selectors[meth.sel] = meth
	
end
