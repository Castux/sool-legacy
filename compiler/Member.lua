require 'class'

require 'Type'

Member = class()

function Member:init(context,node)
	
	-- Attributes
	
	self.private = false
	self.type = nil
	self.name = ''
	
	-- Original class
	
	self.klass = nil
	
	-- Context
	
	self.context = context
	self.node = node
	
	self.name_node = nil
	
	return self
end

function Member:validate()
	
	local n = self.node
	
	assert(n.rule.name == 'member definition')
	
	-- Privacity
	
	if not n.nodes[1]:isa(EmptyNode) then
		self.private = true
	end
	
	-- Type
	
	self.type = Type()
	if not self.type:validate(self.context,n.nodes[2]) then
		return false
	end
	
	-- Name
	
	self.name_node = n.nodes[3]
	self.name = n.nodes[3].value
	
	return true
end
