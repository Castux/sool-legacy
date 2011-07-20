require 'class'

-- In this file we define all the abstract nodes that are direct translations
-- of the parse tree.

------------------
-- AbstractNode --
------------------

-- This is the root class for the abstract syntax tree.
-- Any AbstractNode as member or in a member list is considered a child,
-- except the member "parent".

-- That ensures proper traversal.
-- Parents can be set later with a pass, but then must be kept up to date
-- if any node needs access to its hierarchy (and they usually do).

AbstractNode = class()

function AbstractNode:init()
	
	self.node = nil		-- parse tree node, filled in by the parser
	
	return self
end

function AbstractNode:children()
	
	local c = {}
	
	for k,v in pairs(self) do
		if k ~= 'parent' and type(v) == 'table' then
		
			if v.isa and v:isa(AbstractNode) then
				table.insert(c,v)
			else
				for l,w in ipairs(v) do
					if w.isa and w:isa(AbstractNode) then
						table.insert(c,w)
					end
				end
			end
		end
	end
	
	return c
end

function AbstractNode:replace_child(old,new)
	
	for k,v in pairs(self) do
		if v == old then
			self[k] = new
			print('replaced key')
			return
		
		elseif type(v) == 'table' and not v.isa then
			for i,w in ipairs(v) do
				if w == old then
					v[i] = new
					print('replaced in list')
					return
					
				end
			end
		end
	end
	
	error('Node not found')
end

function AbstractNode:to_string()
	error('Override this')
end

function AbstractNode:indent(str)
	return '| ' .. str:gsub('\n','\n| ')
end

function AbstractNode:get_parent(klass)
	
	local current = self.parent
	while current do
		if current.class == klass then
			return current
		end
		
		current = current.parent
	end
	
	return nil
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
	
	self.child_classes = {}		-- Filled in by analyzer
	
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

function Member:to_string()
	
	local s = 'private: ' .. tostring(self.private) .. '\n'
	s = s .. self.type:to_string() .. '\n'
	s = s .. 'name: ' .. self.name
	
	return 'Member:\n' .. self:indent(s)
end

-----------
-- Types --
-----------

Type = class(AbstractNode)

function Type:init()
	return self
end

----------------
-- SimpleType --
----------------

SimpleType = class(Type)

function SimpleType:init()
	return self
end

function SimpleType:parse(n)
	self.node = n
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

function NumberType:signature()
	return 'num'
end

function StringType:signature()
	return 'str'
end

function VectorType:signature()
	return 'vec'
end

function SymbolType:signature()
	return 'sym'
end

---------------
-- ArrayType --
---------------

ArrayType = class(Type)

function ArrayType:init(sub)
	
	self.subtype = sub
	
	return self
end

function ArrayType:to_string()
	return 'ArrayType:\n' .. self:indent(self.subtype:to_string())
end

function ArrayType:signature()
	return '[' .. self.subtype:signature() .. ']'
end

---------------
-- TableType --
---------------

TableType = class(Type)

function TableType:init(key,value)
	
	self.keytype = key
	self.valuetype = value
	
	return self
end

function TableType:to_string()
	return 'TableType:\n' .. self:indent(self.keytype:to_string() .. '\n' .. self.valuetype:to_string())
end

function TableType:signature()
	return '{' .. self.keytype:signature() .. ',' .. self.valuetype:signature() .. '}'
end

---------------
-- ClassType --
---------------

ClassType = class(Type)

function ClassType:init(name)
	
	self.class_name = name
	
	return self
end

function ClassType:to_string()
	return 'ClassType:\n' .. self:indent('class name: ' .. self.class_name)
end

function ClassType:signature()
	return self.class_name
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

function Argument:to_string()
	
	local s = self.type:to_string() .. '\nname: ' .. self.name
	
	return 'Argument:\n' .. self:indent(s)
end

-----------
-- Block --
-----------

Block = class(AbstractNode)

function Block:init(stats,final)
	
	self.stats = stats
	
	table.insert(self.stats,final)
	
	self.locals = {}	-- Filled by lexical analysis
	
	return self
end

function Block:to_string()
	local t = {}
	
	for i,v in ipairs(self.stats) do
		table.insert(t,v:to_string())
	end
	
	return 'Block:\n' .. self:indent(table.concat(t,'\n'))
end

-------------------------
-- Break, Skip, Return --
-------------------------

Break = class(AbstractNode)

function Break:init()
	
	return self
end

function Break:to_string()
	return 'Break'
end

Skip = class(AbstractNode)

function Skip:init()
	
	return self
end

function Skip:to_string()
	return 'Skip'
end

Return = class(AbstractNode)

function Return:init(rvals)
	
	self.rvals = rvals
	
	return self
end

function Return:to_string()
	
	if #self.rvals > 0 then
		local t = {}
		
		for i,v in ipairs(self.rvals) do
			table.insert(t,v:to_string())
		end
		
		return 'Return:\n' .. self:indent(table.concat(t,'\n'))
	
	else
		return 'Return'
	end
end

----------------
-- Expression --
----------------

Expression = class(AbstractNode)

function Expression:init()
	return self
end

------------------------
-- Atomic expressions --
------------------------

AtomicNumber = class(Expression)

function AtomicNumber:init(val)
	
	self.val = val
	
	return self
end

function AtomicNumber:to_string()
	return 'AtomicNumber:\n' .. self:indent(self.val)
end

AtomicString = class(Expression)

function AtomicString:init(val)
	
	self.val = val
	
	return self
end

function AtomicString:to_string()
	return 'AtomicString:\n' .. self:indent(self.val)
end

AtomicBool = class(Expression)

function AtomicBool:init(val)
	
	self.val = val
	
	return self
end

function AtomicBool:to_string()
	return 'AtomicBool:\n' .. self:indent(tostring(self.val))
end

AtomicSymbol = class(Expression)

function AtomicSymbol:init(val)
	
	self.val = val
	
	return self
end

function AtomicSymbol:to_string()
	return 'AtomicSymbol:\n' .. self:indent(self.val)
end

AtomicNil = class(Expression)

function AtomicNil:init(val)
	
	return self
end

function AtomicNil:to_string()
	return 'AtomicNil'
end

------------------
-- Constructors --
------------------

ArrayCons = class(Expression)

function ArrayCons:init(exps)
	
	self.exps = exps
	
	return self
end

function ArrayCons:to_string()
	
	local t = {}
	
	for i,v in ipairs(self.exps) do
		table.insert(t,v:to_string())
	end
	
	return 'ArrayCons:\n' .. self:indent(table.concat(t,'\n'))
end

VectorCons = class(Expression)

function VectorCons:init(exps)
	
	self.exps = exps
	
	return self
end

function VectorCons:to_string()
	
	local t = {}
	
	for i,v in ipairs(self.exps) do
		table.insert(t,v:to_string())
	end
	
	return 'VectorCons:\n' .. self:indent(table.concat(t,'\n'))
end

TableCons = class(Expression)

function TableCons:init(kvpairs)
	
	self.pairs = kvpairs
	
	return self
end

function TableCons:to_string()
	
	local t = {}
	
	for i,v in ipairs(self.pairs) do
		table.insert(t,v.key:to_string())
		table.insert(t,v.value:to_string())
	end
	
	return 'TableCons:\n' .. self:indent(table.concat(t,'\n'))
end

ObjectCons = class(Expression)

function ObjectCons:init(cname,args)
	
	self.class_name = cname
	
	if args and args.isa then
		self.args = {args}
	elseif args then
		self.args = args
	else
		self.args = {}
	end
	
	return self
end

function ObjectCons:to_string()
	
	local s = 'class: ' .. self.class_name .. '\n'
	
	local t = {}
	for i,v in ipairs(self.args) do
		table.insert(t,v:to_string())
	end
	
	s = s .. table.concat(t,'\n')
	
	return 'ObjectCons:\n' .. self:indent(s:gsub('\n$',''))
end

----------------
-- MethodCall --
----------------

MethodCall = class(Expression)

function MethodCall:init(left,name,args)
	
	self.left = left
	self.name = name
	
	if args and args.isa then
		self.args = {args}
	elseif args then
		self.args = args
	else
		self.args = {}
	end
	
	return self
end

function MethodCall:to_string()
	
	local s = (self.left and self.left:to_string() or '<none>') .. '\n'
	s = s .. 'name: ' .. self.name .. '\n'
	
	local t = {}
	for i,v in ipairs(self.args) do
		table.insert(t,v:to_string())
	end
	
	s = s .. table.concat(t,'\n')
	
	return 'MethodCall:\n' .. self:indent(s:gsub('\n$',''))
end

--------------
-- Indexing --
--------------

Indexing = class(Expression)

function Indexing:init(expr)
	
	self.left = nil
	self.exp = expr
	
	return self
end

function Indexing:to_string()
	
	local s = (self.left and self.left:to_string() or '<none>') .. '\n'
	s = s .. self.exp:to_string()
	
	return 'Indexing:\n' .. self:indent(s)
end

--------------------
-- UnaryOperation --
--------------------

UnaryOperation = class(Expression)

function UnaryOperation:init(unop,expr)
	
	self.unop = unop
	self.exp = expr
	
	return self
end

function UnaryOperation:to_string()
	
	local s = 'unop: ' .. self.unop .. '\n'
	s = s .. self.exp:to_string()
	
	return 'UnaryOperation:\n' .. self:indent(s)
end

---------------------
-- BinaryOperation --
---------------------

BinaryOperation = class(Expression)

function BinaryOperation:init(binop,expr)
	
	self.left = nil
	self.binop = binop
	self.right = expr
	
	return self
end

function BinaryOperation:to_string()
	
	local s = (self.left and self.left:to_string() or '<none>') .. '\n'
	s = s .. 'binop: ' .. self.binop .. '\n'
	s = s .. self.right:to_string()
	
	return 'BinaryOperation:\n' .. self:indent(s)
end

-------------------------------------------
-- For basic_exp, left_value, expression --
-------------------------------------------

-- This function expects a node and a list of nodes,
-- and restores left derivation

function LeftDerivation(left,tails)
	
	local left = left
	
	for i,v in ipairs(tails) do
		v.left = left
		left = v
	end
	
	return left
end

--------
-- Do --
--------

Do = class(AbstractNode)

function Do:init(block)
	
	self.body = block
	
	return self
end

function Do:to_string()
	return 'Do:\n' .. self:indent(self.body:to_string())
end

-----------
-- While --
-----------

While = class(AbstractNode)

function While:init(cond,name,body)
	
	self.cond = cond
	self.name = name
	self.body = body
	
	return self
end

function While:to_string()
	
	local s = self.cond:to_string() .. '\n'
	s = s .. 'local name of cond: ' .. (self.name or '<none>') .. '\n'
	s = s .. self.body:to_string()
	
	return 'While:\n' .. self:indent(s)
end

--------
-- If --
--------

If = class(AbstractNode)

-- alts = { cond = Expression, body = Block, name = string }

function If:init(alts,default,name)
	
	self.conds = {}
	self.bodies = {}
	self.names = {}
	
	self.nodes = {}
	
	for i,v in ipairs(alts) do
		self.conds[i] = v.cond
		self.bodies[i] = v.body
		self.names[i] = v.name
		self.nodes[i] = v.node
	end
	
	self.default = default

	return self
end

function If:to_string()
	
	local t = {}
	
	for i = 1,#self.conds do
		table.insert(t, self.conds[i]:to_string())
		table.insert(t, self.bodies[i]:to_string())
		table.insert(t, self.names[i] or '<none>')
	end
	
	if self.default then
		table.insert(t, self.default:to_string())
	end
	
	s = table.concat(t,'\n')
	
	return 'If:\n' .. self:indent(s)
end

---------
-- For --
---------

For = class(AbstractNode)

function For:init(names,exps,body)
	
	self.names = names
	self.exps = exps
	self.body = body
	
	return self
end

function For:to_string()
	
	local t = {}
	
	for i,v in ipairs(self.names) do
		table.insert(t,'name: ' .. v)
	end
	
	for i,v in ipairs(self.exps) do
		table.insert(t,v:to_string())
	end
	
	table.insert(t,self.body:to_string())
	
	return 'For:\n' .. self:indent(table.concat(t,'\n'))
end

----------------
-- Assignment --
----------------

Assignment = class(AbstractNode)

function Assignment:init(lvals,rvals)
	
	self.lvals = lvals
	self.rvals = rvals
	
	return self
end

function Assignment:to_string()
	
	local t = {'left:'}
	
	for i,v in ipairs(self.lvals) do
		table.insert(t,v:to_string())
	end
	
	table.insert(t, 'right:')
	
	for i,v in ipairs(self.rvals) do
		table.insert(t,v:to_string())
	end
	
	return 'Assignment:\n' .. self:indent(table.concat(t,'\n'))
end
