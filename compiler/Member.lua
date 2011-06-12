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
	
	return self
end

function Member:validate()
	
	local n = self.node
	
	assert(n.rule.name == 'member definition')
	
	-- Privacity
	
	if #n[1] > 0 then
		self.private = true
	end
	
	-- Type
	
	self.type = Type()
	self.type:validate(self.context,n[2])
	
	-- Name
	
	self.name = n[3][1][1][2]
	
end
