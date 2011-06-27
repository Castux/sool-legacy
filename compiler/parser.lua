----------------------
-- Set computations --
----------------------

function set_copy(a)
	
	local res = {}
	for k,v in pairs(a) do
		res[k] = v
	end
	
	return res
end

function set_intersection(a,b)
	
	local res = {}
	
	for k,v in pairs(a) do
		if b[k] then
			res[k] = v
		end
	end
	
	return res
end

function set_union(a,b)
	
	local res = set_copy(a)
	
	for k,v in pairs(b) do
		res[k] = v
	end
	
	return res
end

function set_empty(a)
	
	for k,v in pairs(a) do
		return false
	end
	
	return true
end

function set_print(a)
	
	local t = {}
	
	for k,v in pairs(a) do
		local s
		if type(k) == 'string' then
			s = '\'' .. k .. '\''
		elseif type(k) == 'table' then
			s = k.name or k:to_string()
		end
		table.insert(t,s)
	end
	
	print('{' .. table.concat(t,' :: ') .. '}')
end

function set_clean(set)
	
	for k,v in pairs(set) do
		if not v then
			set[k] = nil
		end
	end
end

-----------
-- Rules --
-----------

Rule = class()

function Rule:init()
	
	self.name = nil		-- a string used for context
	
	return self
end

function Rule:resolve_link(l,g)
	
	if type(l) == 'string' then
		
		if g.rules[l] then
			return g.rules[l]
		else
			error('Rule:resolve_link() - unknown rule \'' .. l .. '\'')
		end
	
	elseif l.isa and l:isa(Rule) then
		l:resolve_links(g)
		return l
	else
		error('Rule:resolve_link() expects strings or Rule objects')
	end
end

function Rule:to_string()
	error('Override this')
end

function Rule:get_name()
	return self.name and self.name:gsub(' ','_') or self:to_string()
end

function Rule:is_epsilon()
	error('Override this')
end

function Rule:get_first_set()
	error('Override this')
end

-- Get all optionals that can end the rule, at any level, and add them to the given set

function Rule:add_rightmost_optionals(set)
	error('Override this')
end

function Rule:get_rightmost_optionals()
	
	local set = {}
	self:add_rightmost_optionals(set)
	
	set_clean(set)
	
	return set
end

-- Get all the optionals from the left (start at 'start'), and the first non optional

function get_left_consecutive_optionals(r,start)
	
	local function do_it(r,start,set)
		
		if r.terminal then
			return
		end
		
		for i = start,#r do
			local v = r[i]
			
			if v.optional or v.repetition then
				set[v] = true
			end
			
			if not is_epsilon(v) then
				set[v] = true
				break
			end
		end
		
	end
	
	local set = {}
	
	-- For choices, we need to do it for each subrule
	if r.choice then
		for i,v in ipairs(r) do
			do_it(v,start,set)
		end
	
	-- For sequences, we apply it directly
	else
		do_it(r,start,set)
	end
	
	return set
end

function validate_rule(r,g)
	
	-- Terminal
	if r.terminal then
		return true
	end
	
	-- Table, do the work
	
	-- Use memoized if any
	if r.valid then
		return true
	end
	
	local ret = true
	
	-- Sequence
	if not r.choice then
		
		-- Need to check that for any optional subrule (or that contains an optional at the end)
		-- that its first set doesn't collide with the one of the following subrules
		
		for i = 1,#r-1 do
			
			local lefts = get_rightmost_optionals(r[i])
			local rights = get_left_consecutive_optionals(r,i+1)
			
			for left,_ in pairs(lefts) do
				for right,_ in pairs(rights) do
				
					local inter = set_intersection(first_set(left),first_set(right))
					
					if not set_empty(inter) then
						print('First/Follow conflict with ' .. rule_name(left) .. ' and ' .. rule_name(right)
							.. ' in ' .. rule_name(r) )
						print('Shared tokens:')
						set_print(inter)
						ret = false
					end
					
				end
			end
			
		end
		
	-- Choice
	else
		
		-- Need to check that no two choices have elements in common in their first sets
		
		for i = 1,#r-1 do
			for j = i+1,#r do
				local inter = set_intersection(first_set(r[i]),first_set(r[j]))
				
				if not set_empty(inter) then
					print('First/First conflict with ' .. rule_name(r[i]) .. ' and ' .. rule_name(r[j])
						.. ' in ' .. rule_name(r) )
					print('Common tokens: ')
					set_print(inter)
					ret = false
				end
			end
		end
		
	end
	
	-- And if it's a repetition, check also the rightmost optionals with the first and possibly followings (loop around)
		
	if r.repetition then
		
		local lefts = get_rightmost_optionals(r)
		
		-- Remove the whole rule, or it would always conflict with its first subrule
		lefts[r] = nil
		
		local rights = get_left_consecutive_optionals(r,1)
		
		for left,_ in pairs(lefts) do
			for right,_ in pairs(rights) do
				
				local inter = set_intersection(first_set(left),first_set(right))
				
				if not set_empty(inter) then
					print('First/Follow conflict (in repetition) with ' .. rule_name(left) .. ' and ' .. rule_name(right)
						.. ' in ' .. rule_name(r) )
					print('Shared tokens:')
					set_print(inter)
					ret = false
				end
			end
		end
		
	end
	
	-- Memoize
	r.valid = true
	
	-- Recurse
	for i,v in ipairs(r) do
		if not validate_rule(v,g) then
			ret = false
		end
	end
	
	return ret
end

--------------
-- Sequence --
--------------

Sequence = class(Rule)

function Sequence:init(t)
	
	if type(t) ~= 'table' or #t <= 1 then
		error('Sequence:init() requires a table with at least two rules in it')
	end
	
	-- Get name
	
	self.name = t.name
	t.name = nil
	
	-- Use rule table directly
	self.rules = t
	
	return self
end

function Sequence:resolve_links(g)
	
	for i,rule in ipairs(self.rules) do
		self.rules[i] = self:resolve_link(rule,g)
	end
end

function Sequence:to_string()
	
	local t = {}
	for i,v in ipairs(self.rules) do
		local str = v:get_name()
		
		if (v:isa(Choice) or v:isa(Sequence)) and not v.name then
			str = '( ' .. str .. ' )'
		end
		
		table.insert(t,str)
	end
	
	return table.concat(t,' ')
end

function Sequence:is_epsilon()
	
	if self.epsilon then
		return true
	end
	
	for i,v in ipairs(self.rules) do
		if not v:is_epsilon() then
			return false
		end
	end
	
	self.epsilon = true
	
	return true
end

function Sequence:get_first_set()
	
	if self.first_set then
		return self.first_set
	end
	
	local first = self.rules[1]:get_first_set()
	
	-- For each consecutive espilon rule we need to add the ones that follow
	for i = 1,#self.rules-1 do
		
		if not self.rules[i]:is_epsilon() then
			break
		end
		
		local follow = self.rules[i+1]:get_first_set()
		first = set_union(first,follow)
	end
	
	self.first_set = first
	return first
end

function Sequence:add_rightmost_optionals(set)
	
	-- Avoid infinite recursion
	if set[self] ~= nil then
		return
	end
	
	set[self] = false		-- prevents recursion and still does not belong to set
	
	-- Call on last rule
	self.rules[#self.rules]:add_rightmost_optionals(set)
	
	-- Must add rules from right to left if the final ones are consecutive epsilons
	local j = #self.rules
	while self.rules[j]:is_epsilon() and j > 1 do
		self.rules[j-1]:add_rightmost_optionals(set)
		j = j-1
	end
	
end

------------
-- Choice --
------------

Choice = class(Rule)

function Choice:init(t)
	
	if type(t) ~= 'table' or #t <= 1 then
		error('Choice:init() requires a table with at least two rules in it')
	end
	
	-- Get name
	
	self.name = t.name
	t.name = nil
	
	-- Use rule table directly
	self.rules = t
	
	return self
end

function Choice:resolve_links(g)
	
	for i,rule in ipairs(self.rules) do
		self.rules[i] = self:resolve_link(rule,g)
	end
end

function Choice:to_string()
	
	local t = {}
	for i,v in ipairs(self.rules) do
		local str = v:get_name()
		
		if v:isa(Choice) and not v.name then
			str = '( ' .. str .. ' )'
		end
		
		table.insert(t,str)
	end
	
	return table.concat(t,' | ')
end

function Choice:is_epsilon()
	
	if self.epsilon then
		return true
	end
	
	for i,v in ipairs(self.rules) do
		if v:is_epsilon() then
			self.epsilon = true
			return true
		end
	end
	
	return false
end

function Choice:get_first_set()
	
	if self.first_set then
		return self.first_set
	end
	
	-- Merge sets for all choices
	
	local first = self.rules[1]:get_first_set()
	
	for i = 2,#self.rules do
		
		local follow = self.rules[i]:get_first_set()
		first = set_union(first,follow)
	end
	
	self.first_set = first
	
	return first
end

function Choice:add_rightmost_optionals(set)
	
	-- Avoid infinite recursion
	if set[self] ~= nil then
		return
	end
	
	set[self] = false		-- prevents recursion and still does not belong to set
	
	-- Merge results from all subrules
	for i,v in ipairs(self.rules) do
		v:add_rightmost_optionals(set)
	end
	
end

--------------
-- Terminal --
--------------

Terminal = class(Rule)

function Terminal:init(arg)
	
	if type(arg) == 'table' then
		
		if #arg ~= 1 or type(arg[1]) ~= 'string' then
			error('Terminal:init() requires a table with exactly one string in it')
		end
		
		self.name = arg.name
		self.token = arg[1]
	
	else
		
		if type(arg) ~= 'string' then
			error('Terminal:init() requires a single string argument')
		end
		
		self.token = arg
	end
	
	return self
end

function Terminal:resolve_links(g)
	return
end

function Terminal:to_string()
	return '\'' .. self.token .. '\''
end

function Terminal:is_epsilon()
	return false
end

function Terminal:get_first_set()
	return { [self.token] = true }
end

function Terminal:add_rightmost_optionals(set)
	return
end

----------------
-- Repetition --
----------------

Repetition = class(Rule)

function Repetition:init(t)

	if type(t) ~= 'table' or #t ~= 1 then
		error('Repetition:init() requires a table with exactly one rule in it')
	end
	
	self.name = t.name
	
	self.rule = t[1]
	
	return self
end

function Repetition:resolve_links(g)
	self.rule = self:resolve_link(self.rule,g)
end

function Repetition:to_string()
	return '{ ' .. self.rule:get_name() .. ' }'
end

function Repetition:is_epsilon()
	return true
end

function Repetition:get_first_set()
	return self.rule:get_first_set()
end

function Repetition:add_rightmost_optionals(set)
	
	-- Avoid infinite recursion
	if set[self] ~= nil then
		return
	end
	
	-- Add self
	set[self] = true
	
	-- Call on child
	self.rule:add_rightmost_optionals(set)
end

--------------
-- Optional --
--------------

Optional = class(Rule)

function Optional:init(t)

	if type(t) ~= 'table' or #t ~= 1 then
		error('Optional:init() requires a table with exactly one rule in it')
	end
	
	self.name = t.name
	
	self.rule = t[1]
	
	return self
end

function Optional:resolve_links(g)
	self.rule = self:resolve_link(self.rule,g)
end

function Optional:to_string()
	return '[ ' .. self.rule:get_name() .. ' ]'
end

function Optional:is_epsilon()
	return true
end

function Optional:get_first_set()
	return self.rule:get_first_set()
end

function Optional:add_rightmost_optionals(set)
	
	-- Avoid infinite recursion
	if set[self] ~= nil then
		return
	end
	
	-- Add self
	set[self] = true
	
	-- Call on child
	self.rule:add_rightmost_optionals(set)
end

---------------
-- NamedRule --
---------------

NamedRule = class(Rule)

function NamedRule:init(t)

	if type(t) ~= 'table' or #t ~= 1 then
		error('NamedRule:init() requires a table with exactly one rule in it')
	end
	
	if not t.name then
		error('NamedRule:init() requires a table with a non nil \'name\' field')
	end
	
	self.name = t.name
	
	self.rule = t[1]
	
	return self
end

function NamedRule:resolve_links(g)
	self.rule = self:resolve_link(self.rule,g)
end

function NamedRule:to_string()
	return self.rule:get_name()
end

function NamedRule:is_epsilon()
	return self.rule:is_epsilon()
end

function NamedRule:get_first_set()
	return self.rule:get_first_set()
end

function NamedRule:add_add_rightmost_optionals(set)
	self.rule:add_rightmost_optionals(set)
end
-------------
-- Grammar --
-------------

Grammar = class()

function Grammar:init(g,entry)
	
	self.rules = g
	
	self:validate()
	
	self.entry = entry
	
	
	return self
end

function Grammar:validate()
	
	-- Don't do it twice
	
	if self.valid then
		return true
	end
	
	-- Replace named rules by references
	
	for k,rule in pairs(self.rules) do
		rule:resolve_links(self)
	end
	
	self.valid = true
	for k,rule in pairs(self.rules) do
		print(rule.name or '<anon>', '::=', rule:to_string() )
		
		set_print(rule:get_rightmost_optionals())
	end
		
	return true
end


---------------------
-- Parsing context --
---------------------

ParsingContext = class()

function ParsingContext:init(tokens,grammar)
	
	-- Tokens
	
	self.tokens = tokens
	self.current = 1		-- the current look ahead. Number of parsed token is "current-1"
	
	-- Grammar
	
	if not grammar:validate() then
		os.exit(1)
	end
	
	self.grammar = grammar	
	
	-- Error handling
	
	self.errors = {}
	self.last_opt = {}		-- the last optional rules that didn't match. Clean it every time a token is consumed. That gives nicer error messages.
	
	return self
end

function ParsingContext:consume()
	self.current = self.current + 1
	
	-- Hey, success, forget the last optionals
	self.last_opt = {}
end

function ParsingContext:peek()
	return self.tokens[self.current]
end

function ParsingContext:format_opt()
	
	local str = ""
	
	for i,opt in ipairs(self.last_opt) do
		if i == #self.last_opt then
			str = str .. ' or '
		else
			str = str .. ', '
		end
		
		str = str .. rule_name(opt)
	end
	
	return str
end

function ParsingContext:expect(tok,node)
	
	local head = self:peek()
	
	if head.kind == tok then
		table.insert(node,head)
		self:consume()
		return true
	else
		
		local str = '\'' .. tok .. '\'' .. self:format_opt()
		
		self:adderror('error','expected ' .. str .. ', found \'' .. head.value .. '\' instead', head.pos)
		return false
	end
end

function ParsingContext:adderror(typ,mess,pos)

	local err = {'Parser', typ, mess, pos}
	table.insert(self.errors,err)
end
	
function ParsingContext:parse()
	return self:parse_rule(self.grammar.nova_entry)
end

-- Returns: success (bool), node, context requested (bool)
function ParsingContext:parse_rule(r)
	
	local nodes = {}
	nodes.rule = r
	
	local node = {}
	node.rule = r
	
	-- Terminal
	if r.terminal then
		
		if not self:expect(r[1],node) then
			return false,node,true
		else
			return true,node
		end
	end
	
	local first = first_set(r)
	
	while true do
		
		node = {}
		node.rule = r
		
		local function retnode()
			if r.repetition then
				return nodes
			else
				return node
			end
		end
		
		-- Check that we can apply this rule
		local head = self:peek()
		if not first[head.kind] then
			
			-- It's ok, return success and the node how it is now (empty for optional, with the already parsed things for repetition)
			if is_epsilon(r) then
				
				-- Remember me
				if r.choice then
					for i,sub in ipairs(r) do
						table.insert(self.last_opt,sub)
					end
				elseif not r.name and r[1] then
					table.insert(self.last_opt,r[1])
				else
					table.insert(self.last_opt,r)
				end
				
				return true,retnode()
			
			else
				local expected = ""
				local count = 0
				for k,v in pairs(first) do
					expected = expected .. "'" .. k .. "' "
					count = count + 1
				end
				expected = expected:sub(1,#expected-1)
				
				if count > 1 then
					expected = 'one of ' .. expected
				end
				
				self:adderror('error','failed to parse ' .. rule_name(r) .. ': expected ' .. expected .. ', found \'' .. head.value .. '\' instead', head.pos)
				
				-- Rule reminder if it has a name. Also, if it contains only one subrule, it's probably a "context" name, so put the inside rule instead
				if r.name then
					self:adderror('info', r.name .. ' := ' .. rule_to_string( #r == 1 and r[1] or r ))
				end
				
				return false,retnode(),true
			end
		
		end
		
		-- Sequence
		if not r.choice then
			
			for i,sub in ipairs(r) do
				
				local succ,subnode,info = self:parse_rule(sub)
				
				table.insert(node,subnode)
				
				if not succ then
					if info and r.name then
						-- Give context
						self:adderror('info','in ' .. rule_name(r) .. ' started here:', node_start(node))
						
						return false,retnode()
					end
					
					return false,retnode(),info
				end
				
			end
			
		-- Choice
		else
			
			for i,sub in ipairs(r) do
				
				local first = first_set(sub)
				
				if first[head.kind] then
					local succ,subnode,info = self:parse_rule(sub)
					
					if not succ then
						return false,retnode(),info
					else
						node = subnode
					end
				end
			end
			
		end
		
		-- Should we stop or continue?
		if not r.repetition then
			return true,retnode()
		else
			table.insert(nodes,node)
		end
	end
	
	error('Unreachable')
end
	

---------------
-- Utilities --
---------------

function node_start(n)
	
	if not n then return nil end
	
	if n.token then
		return n[3]
	else
		-- Return the first non empty node
		for i,v in ipairs(n) do
			if #v > 0 then
				return node_start(n[i])
			end
		end
	end
	
end

function node_end(n)
	
	if not n then return nil end
	
	if n:isa(Token) then
		return n.pos
	else
		for i = #n,1,-1 do
			if #n[i] > 0 then
				return node_end(n[i])
			end
		end
	end
end
	
function node_pos(n)
	return node_start(n):range(node_end(n))
end

-- Return useful nodes in lists such as " subtype { ',' subtype } "

function flatten_list(l)
	local nodes = {}
	
	table.insert(nodes,l[1])
	
	for i,v in ipairs(l[2]) do
		table.insert(nodes,v[2])
	end
	
	return nodes
end

-- Public global functions

dofile 'sool_grammar.lua'

function parse(tokens)
	
	local context = ParsingContext(tokens,SoolGrammar)
	
	local success,node = context:parse()
	
	print_tree(node)
	print''
	
	return context.errors,node
end

function print_tree(t,lev)
	
	local lev = lev or 0
	
	local indent = string.rep("| ",lev)
	
	if not t then return end
	
	if t.isa and t:isa(Token) then
		io.write(indent,"'",t.kind,"': ",t.value,'\n')
	
	else
		
		if #t == 0 then
			io.write(indent, rule_name(t.rule), ': <empty>\n')
		elseif #t == 1 and t[1].token then
			print_tree(t[1],lev)
		else
			io.write(indent, rule_name(t.rule), ': {\n')
			
			for i,v in ipairs(t) do
				print_tree(v,lev+1)
			end
			io.write(indent,'}\n')
		end
	end
end
