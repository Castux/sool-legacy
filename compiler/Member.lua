require 'class'

Member = class()

function Member:init(context,node)
	
	-- Attributes
	
	self.private = false
	self.weak = false
	self.type = nil
	self.name = ''
	
	-- Original class
	
	self.class = nil
	
	-- Context
	
	self.context = context
	self.node = node
	
	return self
end

function Member:validate()
	
	local n = self.node
	
	-- Privacity
	
	if #n[1] > 0 then
		self.private = true
	end
	
	-- Type
	
	-- Name
	
	self.name = n[3][1][1][2]
	
end
