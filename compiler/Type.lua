require 'class'

require 'BuiltInClass'

-- A type is meant to qualify variables: it combines the class of the 
-- pointed objects, and the ownership.

-- It can have a single value (for members, arguments, locals)
-- or multiple values (for method argument lists, return values, and multiple assignments)

SingleType = class()

function SingleType:init()
	
	self.weak = false
	self.klass = nil
	
	return self
end

Type = class()

function Type:init()
	
	-- Content
	
	self.types = {}		-- List of single types, potentially empty (void), or with only one
	
	-- Context
	
	self.node = nil
	self.context = nil
	
	return self
end

function Type:validate(context,node)
	
	assert( node.rule.name == 'type declaration' )
	
	self.node = node
	self.context = context
	
	local single = SingleType()
	
	-- Weakness
	
	if #node[1] > 0 then
		single.weak = true
	end
	
	-- Built-in basic classes
	
	local t = node[2][1][1]
	
	if t == 'num' then
		single.klass = Number
	elseif t == 'str' then
		single.klass = String
	elseif t == 'vec' then
		single.klass = Vector
	elseif t == 'sym' then
		single.klass = Symbol
	
	-- User made class
	
	elseif t == 'ClassName' then
		
		local cname = node[2][1][2]
		local class = context.classes[cname]
		
		if not class then
			context:adderror('unknown class ' .. cname, node[2][1][3])
		else
			single.klass = class
		end
	
	-- Templated built-ins. Scary.
	
	elseif node[2].rule.name == 'array type' then
		
		local subtype = Type()
		if not subtype:validate(context,node[2][2][1]) then
			return false
		end
		
		single.klass = Array(subtype)
		
	elseif node[2].rule.name == 'list type' then

		local subtype = Type()
		if not subtype:validate(context,node[2][2][1]) then
			return false
		end
		
		single.klass = List(subtype)

	elseif node[2].rule.name == 'table type' then

		local ktype = Type()
		if not ktype:validate(context,node[2][2][1]) then
			return false
		end

		local vtype = Type()
		if not vtype:validate(context,node[2][4][1]) then
			return false
		end
		
		single.klass = Table(ktype,vtype)
	
	else
		error('Invalid type declaration node: ' .. t)
	end
	
	-- Validity of ownership
	
	if single.weak and (
		single.klass == Number or
		single.klass == Vector or
		single.klass == Symbol ) then
		
		context:adderror('cannot set ownership information with always-copied type ' .. single.klass.name,node[1][1][1][3])
		return false
	end
	
	-- Build Type wrapper for SingleType
	
	table.insert(self.types,single)
	
	return true
end

function Type:validate_list(context,node)
	
	
	
end
