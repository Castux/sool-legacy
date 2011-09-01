require 'class'

require 'Type'

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
	
	-- Marking treated nodes to avoid multiple traversal
	-- (the tree can get a slightly graph-y structure after a while
	self.done = {}
	
	-- Ref to analyzer for error collecting
	self.analyzer = nil
	
	return self
end

function Pass:apply(node,parent)
	
	if self.done[node] then
		return
	end
	
	self.done[node] = true
	
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
	
	print(context:to_string())
	
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

function Analyzer:add_warning(message,pos)
	local err = {'Analyzer','warning',message,pos}
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

SoolAnalyzer:add_pass( Pass('reject_invalid_lvalues','top-down') )

function Assignment:reject_invalid_lvalues(a)
	
	for i,v in ipairs(self.lvals) do
		if v:isa(MethodCall) and (#v.args ~= 0 or v.args.parens) then
			a:add_error('invalid left value', v.node:position())
			a:add_info('left values cannot end in method calls with arguments')
		end
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

function ClassTypeDecl:check_type_declarations(a)
	
	if not a.classes[self.class_name] then
		a:add_error('unknown class ' .. self.class_name, self.node:position())
		return
	end
	
end

SoolAnalyzer:add_pass( Pass('nested_types_madness','bottom-up') )

function SimpleTypeDecl:nested_types_madness(a)
	self.level = 0
end

function ClassTypeDecl:nested_types_madness(a)
	self.level = 0
end

function ArrayTypeDecl:nested_types_madness(a)
	self.level = self.subtype.level + 1
	
	if self.level >= 4 and not self.parent:isa(TypeDecl) then
		a:add_warning('type has ' .. self.level .. ' nested levels. THIS IS MADNESS.', self.node:position())
	end
end

function TableTypeDecl:nested_types_madness(a)
	self.level = math.max(self.keytype.level + 1, self.valuetype.level + 1)
	
	if self.level >= 4 and not self.parent:isa(TypeDecl) then
		a:add_warning('type has ' .. self.level .. ' nested levels. THIS IS MADNESS.', self.node:position())
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

------------------------------
-- Lexical scoping analysis --
------------------------------

SoolAnalyzer:add_pass( Pass('collect_locals','top-down') )

-- Lists of locals are held by blocks

Local = class(AbstractNode)

function Local:init(name,arg,type)
	
	self.type = type
	self.name = name
	
	self.arg = arg or false
	
	-- Declaration position
	self.pos = nil
	
	return self
end

function Local:kind()
	return self.arg and 'argument' or 'local'
end

function Local:to_string()
	return 'Local: ' .. self.name
end

-- Blocks must be able to scan their own scopes
-- And add locals to it with verifications

function Block:in_scope(name)
	
	local loc = self.locals[name]
	if loc then return loc end
	
	local klass = self:get_parent(Class)
	local mem = klass.members[name]
	if mem then return mem end
	
	local meth
	for i,v in ipairs(klass.methods) do
		if v.name == name then
			meth = v
			break
		end
	end
	if meth then return meth end
	
	return nil
end

function Block:add_local(l,a)
	
	-- Is the name taken already?
	
	local other = self:in_scope(l.name)
	
	if not other then
		-- No, cool.
		self.locals[l.name] = l
		l.parent = self
		return
	end
	
	-- Already a local
	
	if other:isa(Local) then
		a:add_error(l:kind() .. ' declaration shadows ' .. other:kind(), l.pos)
		a:add_info('declared here:', other.pos)
		return
	end
	
	-- A class member maybe?
	
	if other:isa(Member) then
		a:add_error(l:kind() .. ' declaration shadows class member', l.pos)
		a:add_info('declared here:', other.node:position())
		return
	end
	
	-- A method, perhaps.
	
	if other:isa(Method) then
		a:add_error(l:kind() .. ' declaration shadows method name', l.pos)
		a:add_info('declared here:', other.node:position(4,4))
		return
	end
	
	error('What the hell is "other" then?')
end

-- Locals are declared as arguments, and in "as" thingies of whiles and ifs
-- Locals are implicitely declared in assignments to unknown names

function Method:collect_locals(a)
	
	for i,arg in ipairs(self.args) do
		local loc = Local(arg.name, arg.type, true)
		loc.pos = arg.node:position()
		
		self.body:add_local(loc,a)
	end
end

function While:collect_locals(a)
	
	if self.name then
		local loc = Local(self.name)
		loc.pos = self.node.nodes[3]:position(2,2)

		self.body:add_local(loc,a)
	end
end

function If:collect_locals(a)
	
	for i,b in ipairs(self.bodies) do
		if self.names[i] then
			local loc = Local(self.names[i])
			loc.pos = self.nodes[i].nodes[3]:position(2,2)
			
			self.bodies[i]:add_local(loc,a)
		end
	end
	
end

function Assignment:collect_locals(a)
	
	for i,v in ipairs(self.lvals) do
		if v:isa(MethodCall) and not v.left then
			
			local block = self:get_parent(Block)
			local other = block:in_scope(v.name)
			
			if not other then
				
				-- Create new local
				
				local loc = Local(v.name)
				loc.pos = v.node:position()
				
				block:add_local(loc,a)
			end
		end
	end
end

-- Blocks also need to inherit locals from outer blocks. Top-down traversal ensures correctness.
-- Careful though, some block have their variables set by outer nodes (who are treated first). So
-- actually we have a bastardized up-down-up-down zigzaggy traversal of lols.
-- But that'll work out ok.

function Block:collect_locals(a)
	
	local outer = self:get_parent(Block)
	
	if not outer then
		return
	end
	
	for name,loc in pairs(outer.locals) do
	
		local own = self.locals[name]
		if own then
			a:add_error(own:kind() .. ' declaration shadows ' .. loc:kind(), own.pos)
			a:add_info('declared here:', loc.pos)
		else
			self.locals[name] = loc
		end
	end
	
end

SoolAnalyzer:add_pass( Pass('discriminate_locals','top-down') )

-- The grammar uses the "MethodCall" both for actual method calls, and evaluation or assignment to locals
-- Now that we know all the locals' names, we can see the difference.

function MethodCall:discriminate_locals(a)
	
	-- There is ambiguity only for calls without an object and without arguments
	if self.left or #self.args > 0 then
		return
	end
	
	local block = self:get_parent(Block)
	local loc = block.locals[self.name]
	
	-- There is indeed a local by that name. Replace the old node with the Local.
	if loc then
		return loc
	end
end
