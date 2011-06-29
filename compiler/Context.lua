require 'class'

require 'Class'

Context = class()

function Context:init()
	
	-- List of classes, also indexed by names
	
	self.classes = {}
	
	-- Reference to parse tree
	
	self.node = nil
	
	-- Errors during validation
	
	self.errors = {}
	
	return self
end

function Context:adderror(mess, pos)
	local err = {'Analyzer', 'error', mess, pos}
	table.insert(self.errors, err)
end

function Context:addinfo(mess, pos)
	local err = {'Analyzer', 'info', mess, pos}
	table.insert(self.errors, err)
end

-- Entry point of the analyzer

function Context:validate(class_nodes)
	
	-- 1. Build class objects, give them names
	
	for i,node in ipairs(class_nodes) do
		
		assert(node.rule.name == 'class definition')
		
		local c = Class(self,node)
		
		-- Check name collision
		if self.classes[c.name] then
			self:adderror('class ' .. c.name .. ' was already defined', c.name_node.pos)
			self:addinfo('here:', self.classes[c.name].name_node.pos)
		else
			table.insert(self.classes, c)
			self.classes[c.name] = c
		end
	end
	
	-- 2. Build class hierarchy
	
	for i,c in ipairs(self.classes) do
		
		if c.parent_node then
			local pname = c.parent_node.value
			
			-- Check existence of parent class
			local pclass = self.classes[pname]
			if not pclass then
				self:adderror('unknown class ' .. pname, c.parent_node.pos)
			else
				
				-- Check infinite recursion
				local infinite = false
				local names = {c.name}
				local curr = pclass
				
				while true do
					table.insert(names, curr.name)
					
					if curr == c then
						self:adderror('circular inheritence with parent ' .. pname, c.parent_node.pos)
						self:addinfo(table.concat(names,':'))
						infinite = true
						break
					end
					
					curr = curr.parent
					
					if not curr then
						break
					end
				end
				
				if not infinite then
					c.parent = pclass
				end
			end
			
		end
		
	end
	
	-- 3. Build classes' interfaces
	
	for i,c in ipairs(self.classes) do
		c:validate_interface()
	end
	
	return self.errors
end
