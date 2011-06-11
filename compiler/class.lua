require 'class'

Class = class()

function Class:init()
	
	-- Interface
	
	self.name = ''		-- Class name
	self.parent = nil	-- Class parent
	
	self.members = {}	-- List of member objects, including inherited ones
						-- (also indexed by member names)
	
	self.methods = {}	-- List of method objects, including inherited ones
	self.selectors = {}	-- Table of methods indexed by selectors
	
	-- Attributes
	
	self.builtin = false
	
	-- Reference to context
	
	self.context = nil
	
	-- Reference to parse tree
	
	self.node = nil
	
	return self
end
