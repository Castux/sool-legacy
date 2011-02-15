require 'class'

Node = class()

function Node:init()
	
	self.children = {}
	
	return self
end

function Node:accept(tok)

end

-- and then each type of node has its own class with a single parse() method
