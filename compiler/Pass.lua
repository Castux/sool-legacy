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
	
	self.tasks = {}
	
	return self
end

function Pass:apply(node,parent)
	
	local node = node
	local children
	
	if self.dir == 'bottom-up' then
		
		children = node:children()
		
		for i,v in ipairs(children) do
			self:apply(v,node)
		end
	end
	
	local task = self.tasks[node.class]
	if task then
		local ret = task(node)
		
		if ret then
			parent:replace_child(node,ret)
			node = ret
		end
	end
	
	if self.dir == 'top-down' then
		
		children = node:children()
		
		for i,v in ipairs(children) do
			self:apply(v,node)
		end
	end
end


-- Example pass

lol = Pass('lol')
lol.desc = 'do the lulz'
lol.dir = 'bottom-up'

lol.tasks = {
	
	[BinaryOperation] = function(node)
		return MethodCall(node.left,node.binop,node.right)
	end
}
