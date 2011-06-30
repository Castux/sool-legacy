require 'class'

Pass = class()

function Pass:init(name)
	
	-- Info
	self.name = name
	self.desc = ''
	
	-- Traversal order:
	-- 'bottom-up' (postorder depth-first)
	-- 'top-down' (preorder depth-first)
	self.dir = ''
	
	-- Functions indexed by class, to apply on each node
	self.tasks = {}
	
	return self
end

function Pass:apply(node)
	
	local children = node:children()
	
	if self.dir == 'bottom-up' then
		for i,v in ipairs(children) do
			self:apply(v)
		end
	end
	
	local task = self.tasks[node.class]
	
	if task then
		task(node)
	end
	
	if self.dir == 'top-down' then
		for i,v in ipairs(children) do
			self:apply(v)
		end
	end
end
