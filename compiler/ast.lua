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
-- Chunk --
-----------

Chunk = class(AbstractNode)

function Chunk:init(classes)
	
	self.classes = classes
	
	return self
end

function Chunk:to_string()
	local t = {}
	
	for i,v in ipairs(self.classes) do
		table.insert(t,v:to_string())
	end
	
	return 'Chunk:\n' .. self:indent(table.concat(t,'\n'))
end

-----------
-- Class --
-----------

Class = class(AbstractNode)

function Class:init(name,parent,mem_meth)
	
	self.name = name
	self.parent_name = parent
	
	self.members = {}
	self.methods = {}
	
	for i,v in ipairs(mem_meth) do
		
		if v:isa(Member) then
			table.insert(self.members,v)
		elseif v:isa(Method) then
			table.insert(self.methods,v)
		else
			error('Expected Member or Method object')
		end
	end
	
	return self
end

function Class:children()
	return {self.members, self.methods}
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

function Member:init(priv,typ,name)
	
	self.private = priv
	self.type = typ
	self.name = name
	
	return self
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

function Type:init(weak,tclass)
	
	self.weak = weak
	self.tclass = tclass
	
	return self
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

function CompositeType:init(sub)
	
	self.subtype = sub
	
	return self
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

function TableType:init(key,value)
	
	self.keytype = key
	self.valuetype = value
	
	return self
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

function ClassType:init(name)
	
	self.class_name = name
	
	return self
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

function Method:init(priv,rtypes,name,setter,args,body)
	
	self.private = priv
	self.rtypes = rtypes
	
	self.name = name
	self.setter = setter
	
	self.args = args
	self.body = body
	
	return self
end

function Method:children()
	
	local c = {}
	table.append(c,rtypes)
	table.append(c,args)
	table.insert(c,body)
	
	return c
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

function Argument:init(typ,name)
	
	self.type = typ
	self.name = name
	
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

function Block:to_string()
	return 'Block'
end
