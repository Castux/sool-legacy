require 'class'

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
		subtype:validate(context,node[2][2][1])
		
		
		
	elseif node[2].rule.name == 'list type' then
	elseif node[2].rule.name == 'table type' then
	
	end
	
	
	
end

function Type:validate_list(context,node)
	
	
	
end
