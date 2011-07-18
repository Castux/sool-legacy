require 'class'

----------
-- Pass --
----------

Pass = class()

function Pass:init(name,dir)
	
	-- Info
	self.name = name
	
	-- Traversal order:
	-- 'bottom-up' (postorder depth-first)
	-- 'top-down' (preorder depth-first)
	self.dir = dir
	
	if dir ~= 'top-down' and dir ~= 'bottom-up' then
		error('Wrong traversal direction')
	end
	
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
	
	if node[self.name] then
		local ret = node[self.name](node)
		
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

--------------
-- Analyzer --
--------------

Analyzer = class()

function Analyzer:init()
	
	self.passes = {}
	self.errors = {}
	
	return self
end

function Analyzer:validate(context)
	
	-- Apply passes in order
	
	for i,pass in ipairs(self.passes) do
		pass:apply(context)
	end
	
	return self.errors
end

------------------
-- SoolAnalyzer --
------------------

SoolAnalyzer = Analyzer()
