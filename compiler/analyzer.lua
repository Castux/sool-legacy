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
	
	-- Ref to analyzer for error collecting
	self.analyzer = nil
	
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
		local ret = node[self.name](node,self.analyzer)
		
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

function Analyzer:add_pass(pass)
	pass.analyzer = self
	table.insert(self.passes,pass)
end

function Analyzer:add_error(message,pos)
	local err = {'analyzer','error',message,pos}
	table.insert(self.errors,err)
end

function Analyzer:add_info(message,pos)
	local err = {'analyzer','info',message,pos}
	table.insert(self.errors,err)
end

------------------
-- SoolAnalyzer --
------------------

SoolAnalyzer = Analyzer()

SoolAnalyzer:add_pass( Pass('lol','top-down') )

function AbstractNode:lol(a)
	if self.node then
		a:add_info(classname(self.class),self.node:position())
	end
end
