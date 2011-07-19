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
	
	-- Take some shortcut references
	self.classes = context.classes
	
	-- Apply passes in order, stop only if told too
	
	for i,pass in ipairs(self.passes) do
		self:add_info('running pass: ' .. pass.name)
		pass:apply(context)
		
		if self.stop then
			break
		end
	end
	
	return self.errors
end

function Analyzer:add_pass(pass)
	pass.analyzer = self
	table.insert(self.passes,pass)
end

function Analyzer:add_error(message,pos)
	local err = {'Analyzer','error',message,pos}
	table.insert(self.errors,err)
	
	self.stop = true
end

function Analyzer:add_info(message,pos)
	local err = {'Analyzer','info',message,pos}
	table.insert(self.errors,err)
end

------------------
-- SoolAnalyzer --
------------------

SoolAnalyzer = Analyzer()

----------------------
-- AST finalization --
----------------------

SoolAnalyzer:add_pass( Pass('set_parent_nodes','top-down') )

function AbstractNode:set_parent_nodes(a)
	
	local ch = self:children()
	
	for _,child in ipairs(ch) do
		child.parent = self
	end
	
end

----------------------------------
-- Classes' names and hierarchy --
----------------------------------

SoolAnalyzer:add_pass( Pass('check_class_redefinition','top-down') )

function Class:check_class_redefinition(a)
	
	-- Reuse class list for indexing by name
	
	local other = a.classes[self.name]
	if other then
		a:add_error('class ' .. self.name .. ' was already defined', self.node:position(2,2))
		a:add_info('here:', other.node:position(2,2))
	else
		a.classes[self.name] = self
	end
end

-- To establish the hierarchy, we actually move the classes to be children of their parent in the AST

SoolAnalyzer:add_pass( Pass('build_class_hierarchy','top-down') )

function Context:build_class_hierarchy(a)
	
	-- Run on each class, gather only root classes
	-- This needs to be done at Context level, otherwise setting the child classes
	-- during the pass leads to multiple traversal of the children.
	
	local new = {}
	
	for _,c in ipairs(self.classes) do
		local del = c:build_class_hierarchy_helper(a)
		
		if not del then
			table.insert(new,c)
		end
	end
	
	self.classes = new
end

-- Return true if class is derived from another (and thus needs to be removed from the Context's list)

function Class:build_class_hierarchy_helper(a)
	
	-- Avoid all the fuss if we don't even have a parent
	
	local pname = self.parent_name
	if not pname then
		return
	end
	
	-- Does the parent exist?
	
	local pclass = a.classes[pname]
	if not pclass then
		a:add_error('unknown class ' .. pname, self.node.nodes[3].nodes[2]:position())
		return
	end
	
	-- Check circular inheritence
	
	local current = self
	local visited = {}
	local chain = {}
	
	while current do
		table.insert(chain,current.name)
		visited[current] = true
		current = a.classes[current.parent_name]
		
		if visited[current] then
			table.insert(chain,current.name)
			a:add_error('circular inheritance: ' .. table.concat(chain,':'), self.node.nodes[3].nodes[2]:position())
			return
		end
	end
	
	-- Give class to its parent
	
	table.insert(pclass.child_classes, self)
	
	-- Request removal from root list
	
	return true
end

-------------------------
-- Classes' interfaces --
-------------------------

SoolAnalyzer:add_pass( Pass('check_type_declarations','top-down') )

function ClassType:check_type_declarations(a)
	
	if not a.classes[self.class_name] then
		a:add_error('unknown class ' .. self.class_name, self.node:position())
		return
	end
	
end

SoolAnalyzer:add_pass( Pass('check_member_redefinition','top-down') )

function Member:check_member_redefinition(a)
	
	-- Reuse class's member table with name indexing
	local cl = self.parent	
	
	local other = cl.members[self.name]
	if other then
		a:add_error('member ' .. self.name .. ' was already defined in the same class', self.node:position(3,3))
		a:add_info('here:', other.node:position(3,3))
	else
		cl.members[self.name] = self
	end
	
end

SoolAnalyzer:add_pass( Pass('build_method_selectors','top-down') )

function Method:build_method_selectors(a)
	
	-- Gather argument types signatures

	local t = {}
	for _,arg in ipairs(self.args) do
		table.insert(t, arg.type:signature())
	end
	
	local sel = self.name .. ':' .. table.concat(t,',')
	self.sel = sel
	
	-- Reuse class' method table with selector indexing
	
	local other = self.parent.methods[sel]
	if other then
		a:add_error('method with selector ' .. sel .. ' was already defined in the same class', self.node:position(4,7))
		a:add_info('here:', other.node:position(4,7))
		return
	else
		self.parent.methods[sel] = self
	end
	
end

SoolAnalyzer:add_pass( Pass('check_method_member_collision','top-down') )

function Method:check_method_member_collision(a)
	
	local other = self.parent.members[self.name]
	if other then
		a:add_error('method name shadows member', self.node:position(4,4))
		a:add_info('defined here:', other.node:position(3,3))
		return
	end
end
