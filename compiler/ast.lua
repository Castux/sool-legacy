require 'class'

-- In this file we define all the abstract nodes that are direct translations
-- of the parse tree.

------------------
-- AbstractNode --
------------------

-- This is the root class for the abstract syntax tree.
-- The only thing it really does is enforce that nodes can return children,
-- from proper tree traversal by the passes.

AbstractNode = class()

function AbstractNode:init()
	
	return self
end

function AbstractNode:children()
	error('Override this')
end

function AbstractNode:to_string()
	error('Override this')
end

function AbstractNode:indent(str)
	return '| ' .. str:gsub('\n','\n| ')
end

-------------
-- Context --
-------------

-- The root node of the abstract syntax tree.
-- Basically holds the classes, later the symbols, etc. Everything "global".

Context = class(AbstractNode)

function Context:init()
	
	self.classes = {}
	
	return self
end

function Context:parse(chunk)
	
	assert(chunk.rule.name == 'chunk')
	
	for i,v in ipairs(chunk.nodes[1].nodes) do
		local c = Class()
		c:parse(v)
		table.insert(self.classes,c)
	end
end

function Context:children()
	
	return self.classes
end

function Context:to_string()
	local t = {}
	
	for i,v in ipairs(self.classes) do
		table.insert(t,v:to_string())
	end
	
	return 'Context:\n' .. self:indent(table.concat(t,'\n'))
end

-----------
-- Class --
-----------

Class = class(AbstractNode)

function Class:init()
	
	self.name = ''
	self.parent_name = nil
	
	self.members = {}
	self.methods = {}
	
	return self
end

function Class:parse(node)
	
	assert(node.rule.name == 'class definition')
	
	self.node = node
	
	-- Name
	
	self.name_node = node.nodes[2]
	self.name = self.name_node.value
	
	-- Parent name
	
	if not node.nodes[3]:isa(EmptyNode) then
		self.parent_name_node = node.nodes[3].nodes[2]
		self.parent_name = self.parent_name_node.value
	end
	
	-- Members and methods
	
	local mem_met_list = node.nodes[4].nodes
	
	for i,n in ipairs(mem_met_list) do
		if n.rule.name == 'member definition' then
			
			local mem = Member()
			mem:parse(n)
			table.insert(self.members,mem)
		
		elseif n.rule.name == 'method definition' then
			
			local meth = Method()
			meth:parse(n)
			table.insert(self.methods,meth)
		
		else
			error('Wrong node: ' .. n.rule.name)
		end
	end
	
end

function Class:children()
	local c = {}
	table.append(c,self.members)
	table.append(c,self.methods)
	return c
end

function Class:to_string()
	
	local s = 'name: ' .. self.name .. '\n'
	
	s = s .. 'parent name: ' .. (self.parent_name or '<none>') .. '\n'
	
	local t = {}
	for i,v in ipairs(self.members) do
		table.insert(t,v:to_string())
	end
	for i,v in ipairs(self.methods) do
		table.insert(t,v:to_string())
	end
	
	s = s .. table.concat(t,'\n')
	
	return 'Class:\n' .. self:indent(s)
end

------------
-- Member --
------------

Member = class(AbstractNode)

function Member:init()
	
	self.private = false
	self.type = nil
	self.name = ''
	
	return self
end

function Member:parse(n)
	
	assert(n.rule.name == 'member definition')
	
	self.node = n
	
	-- Privacity
	
	if not n.nodes[1]:isa(EmptyNode) then
		self.private = true
	end
	
	-- Type
	
	self.type = Type()
	self.type:parse(n.nodes[2])
	
	-- Name
	
	self.name_node = n.nodes[3]
	self.name = n.nodes[3].value
	
end

function Member:children()
	return {self.type}
end

function Member:to_string()
	
	local s = 'private: ' .. tostring(self.private) .. '\n'
	s = s .. self.type:to_string() .. '\n'
	s = s .. 'name: ' .. self.name
	
	return 'Member:\n' .. self:indent(s)
end

----------
-- Type --
----------

Type = class(AbstractNode)

function Type:init()
	
	self.weak = false
	self.tclass = nil
	
	return self
end

function Type:parse(node)
	
	self.node = node
	
	-- Weakness
	
	if not node.nodes[1]:isa(EmptyNode) then
		self.weak = true
	end
	
	-- TypeClass
	
	local tnode = node.nodes[2]
	local t = tnode.kind
	
	if t == 'num' then
		self.tclass = NumberType()
		self.tclass:parse(tnode)
	elseif t == 'str' then
		self.tclass = StringType()
		self.tclass:parse(tnode)
	elseif t == 'vec' then
		self.tclass = VectorType()
		self.tclass:parse(tnode)
	elseif t == 'sym' then
		self.tclass = SymbolType()
		self.tclass:parse(tnode)
	elseif t == 'ClassName' then
		self.tclass = ClassType()
		self.tclass:parse(tnode)
	elseif tnode.rule.name == 'array type' then
		self.tclass = ArrayType()
		self.tclass:parse(tnode)
	elseif tnode.rule.name == 'list type' then
		self.tclass = ListType()
		self.tclass:parse(tnode)
	elseif tnode.rule.name == 'table type' then
		self.tclass = TableType()
		self.tclass:parse(tnode)
	else
		error('Invalid type declaration node: ' .. t)
	end
end

function Type:children()
	return {self.tclass}
end

function Type:to_string()
	
	local s = 'weak: ' .. tostring(self.weak) .. '\n'
	s = s .. self.tclass:to_string()
	
	return 'Type:\n' .. self:indent(s)
end

----------------
-- SimpleType --
----------------

SimpleType = class(AbstractNode)

function SimpleType:init()
	return self
end

function SimpleType:parse(n)
	self.node = n
end

function SimpleType:children()
	return {}
end

NumberType = class(SimpleType)
StringType = class(SimpleType)
VectorType = class(SimpleType)
SymbolType = class(SimpleType)

function NumberType:to_string()
	return 'NumberType'
end

function StringType:to_string()
	return 'StringType'
end

function VectorType:to_string()
	return 'VectorType'
end

function SymbolType:to_string()
	return 'SymbolType'
end

-------------------
-- CompositeType --
-------------------

CompositeType = class(AbstractNode)

function CompositeType:init()
	
	self.subtype = nil
	
	return self
end

function CompositeType:parse(n)
	
	self.node = n
	
	self.subtype = Type()
	self.subtype:parse(n.nodes[2])
	
end

function CompositeType:children()
	return {self.subtype}
end

ListType = class(CompositeType)
ArrayType = class(CompositeType)

function ListType:to_string()
	return 'ListType:\n' .. self:indent(self.subtype:to_string())
end

function ArrayType:to_string()
	return 'ArrayType:\n' .. self:indent(self.subtype:to_string())
end

---------------
-- TableType --
---------------

TableType = class(AbstractNode)

function TableType:init()
	
	self.keytype = nil
	self.valuetype = nil
	
	return self
end

function TableType:parse(n)
	
	self.node = n
	
	self.keytype = Type()
	self.keytype:parse(n.nodes[2])
	
	self.valuetype = Type()
	self.valuetype:parse(n.nodes[4])
	
end

function TableType:children()
	return {self.keytype,self.valuetype}
end

function TableType:to_string()
	return 'TableType:\n' .. self:indent(self.keytype:to_string() .. '\n' .. self.valuetype:to_string())
end

---------------
-- ClassType --
---------------

ClassType = class(AbstractNode)

function ClassType:init()
	
	self.class_name = ''
	
	return self
end

function ClassType:parse(n)
	self.node = n
	
	self.class_name = n.value
	
end

function ClassType:children()
	return {}
end

function ClassType:to_string()
	return 'ClassType:\n' .. self:indent('class name: ' .. self.class_name)
end

------------
-- Method --
------------

Method = class(AbstractNode)

function Method:init()
	
	self.private = false
	self.rtypes = {}
	self.name = ''
	self.setter = false
	self.args = {}
	self.body = nil
	
	return self
end

function Method:children()
	
	local c = {}
	table.append(c,rtypes)
	table.append(c,args)
	table.insert(c,body)
	
	return c
end

function Method:parse(node)
	
	assert( node.rule.name == 'method definition' )
	
	-- Privacity
	
	if not node.nodes[2]:isa(EmptyNode) then
		self.private = true
	end
	
	-- Return types
	
	if not node.nodes[3]:isa(EmptyNode) then
		local nodes = node.nodes[3]:flatten_list()
		
		for i,v in ipairs(nodes) do
			local t = Type()
			t:parse(v)
			table.insert(self.rtypes,t)
		end
	end
	
	-- Name
	
	local name_node = node.nodes[4]
	
	if name_node.nodes[1].kind == 'Name' then
		
		self.name = name_node.nodes[1].value
		if not name_node.nodes[2]:isa(EmptyNode) then
			self.name = self.name .. '='
			self.setter = true
		end
		
	else
		
		self.name = name_node.nodes[2].value
	end
	
	-- Arguments
	
	local arg_node = node.nodes[6]
	
	if not arg_node:isa(EmptyNode) then
		
		local nodes = arg_node:flatten_list()
		for i,v in ipairs(nodes) do
			local t = Argument()
			t:parse(v)
			table.insert(self.args,t)
		end
	end
	
	-- Body
	
	self.body = Block()
	self.body:parse(node.nodes[8])
	
end

function Method:to_string()
	
	local s = 'private: ' .. tostring(self.private) .. '\n'
	
	local t = {}
	for i,v in ipairs(self.rtypes) do
		table.insert(t,v:to_string())
	end
	
	s = s .. table.concat(t,'\n') .. (#t > 0 and '\n' or '')
	
	s = s .. 'name: ' .. self.name .. '\n'
	s = s .. 'setter: ' .. tostring(self.setter) .. '\n'
	
	local t = {}
	for i,v in ipairs(self.args) do
		table.insert(t,v:to_string())
	end
	
	s = s .. table.concat(t,'\n') .. (#t > 0 and '\n' or '')
	
	s = s .. (self.body and self.body:to_string() or '<no body>')
	
	return 'Method:\n' .. self:indent(s)
end

--------------
-- Argument --
--------------

Argument = class(AbstractNode)

function Argument:init()
	
	self.type = nil
	self.name = ''
	
	return self
end

function Argument:parse(node)
	
	self.node = node
	
	assert( node.rule.name == 'argument definition' )
	
	self.type = Type()
	self.type:parse(node.nodes[1])
	
	self.name = node.nodes[2].value
	
end

function Argument:children()
	return {self.type}
end

function Argument:to_string()
	
	local s = self.type:to_string() .. '\nname: ' .. self.name
	
	return 'Argument:\n' .. self:indent(s)
end

-----------
-- Block --
-----------

Block = class(AbstractNode)

function Block:init()
	
	return self
end

function Block:parse(node)
	
	assert( node.rule.name == 'block' )
	
	self.node = node
	
end

function Block:to_string()
	return 'Block'
end
