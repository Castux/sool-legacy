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
	self.parent = pclass
	
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

SoolAnalyzer:add_pass( Pass('build_methods_type_info','top-down') )

function Method:build_methods_type_info(a)
	
	-- Gather argument types signatures

	local t = {}
	for _,arg in ipairs(self.args) do
		table.insert(t, arg.type:signature())
	end
	
	local sel = self.name .. (self.setter and '=' or '') .. ':' .. table.concat(t,',')
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
	
	-- Gather return types signatures
	t = {}
	for _,ret in ipairs(self.rtypes) do
		table.insert(t, ret:signature())
	end
	
	local retsig = table.concat(t,',')
	self.retsig = retsig
	
	self.sig = retsig .. ':' .. sel
end

SoolAnalyzer:add_pass( Pass('check_method_member_collision','top-down') )

function Method:check_method_member_collision(a)
	
	local other = self.parent.members[self.name]
	if other then
		a:add_error('method definition shadows member', self.node:position(4,4))
		a:add_info('defined here:', other.node:position(3,3))
		return
	end
end

-----------------
-- Inheritance --
-----------------

-- The top-down traversal ensures that a parent inherited its own members/methods already

SoolAnalyzer:add_pass( Pass('inherit_members','top-down') )

function Class:inherit_members(a)
	
	if not self.parent_name then
		return
	end
	
	local mems = self.parent.members
	
	for i,mem in ipairs(mems) do
		local own_mem = self.members[mem.name]
		
		local own_meth
		for i,v in ipairs(self.methods) do
			if v.name == mem.name then
				own_meth = v
			end
		end
		
		if own_mem then
			a:add_error('member definition shadows parent class member', own_mem.node:position(3,3))
			a:add_info('defined here:', mem.node:position(3,3))
		elseif own_meth then
			a:add_error('method definition shadows parent class member', own_meth.node:position(4,4))
			a:add_info('defined here:', mem.node:position(3,3))
		else
			table.insert(self.members,i,mem)
			self.members[mem.name] = mem
		end
	end
	
end

SoolAnalyzer:add_pass( Pass('inherit_methods','top-down') )

function Class:inherit_methods(a)
	
	if not self.parent_name then
		return
	end
	
	local meths = self.parent.methods
	
	for i,meth in ipairs(meths) do
		
		local own_mem = self.members[meth.name]
		local own_meth = self.methods[meth.sel]
		
		if own_mem then
			a:add_error('member definition shadows parent class method', own_mem.node:position(3,3))
			a:add_info('defined here:', meth.node:position(4,4))
		elseif own_meth then
			
			local bad
			
			-- We are overriding the parent. The return types and privacity must match.
			if own_meth.retsig ~= meth.retsig then
				a:add_error('return type mismatch in method definition', own_meth.node:position(3,3))
				a:add_info('overriding parent method:', meth.node:position(3,3))
				bad = true
			end
			
			if own_meth.private ~= meth.private then
				a:add_error('privacity mismatch in method definition', own_meth.node:position(2,2))
				a:add_info('overriding parent method:', meth.node:position(2,2))
				bad = true
			end
			
			if not bad then
				-- We actually replace the old one, so it must take the correct place
				-- Remove from list
				for j,v in ipairs(self.methods) do
					if v == own_meth then
						table.remove(self.methods,j)
					end
				end
				-- Add back in the parent's position
				table.insert(self.methods,i,own_meth)
				-- Replace indexing by selector
				self.methods[own_meth.sel] = own_meth
			end
			
		
		else
			table.insert(self.methods,i,meth)
			self.methods[meth.sel] = meth					
		end
		
	end
end
