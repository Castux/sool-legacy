require 'class'
require 'set'

--[[

This is Nova, a recursive-descent parser for LL(1) grammars.

Building a grammar is done using the following Rule objects

Rule			Argument to init()								Notes and EBNF equivalent
----			------------------								------------------------
Sequence		list of rules and 'name'						Matches each of its subrules in order: a b c
Choice			list of rules and 'name'						Matches exactly one of its subrules: a | b | c
Terminal		string or list with one string and 'name'		Matches a token: 'token'

Optional		list with one rule and 'name'					Matches its subrule 0..1 times: [ rule ]
																Produces a nil node in case of 0
Repetition		list with one rule and 'name'					Matches its subrule 0..inf times: { rule }

NamedRule		list with one rule and 'name'					Matches its subrule. This is used only to wrap a rule for context.
																There is no wrapper node (inside node is produced).

Each "rule" in the given lists can be either a Rule object directly:

	'a' ( 'b' | 'c' ) -> Sequence { Terminal 'a', Choice { Terminal 'b', Terminal 'c' } }

or a reference string to be resolved later (allowing circular reference).

	{ 'a' subrule } -> Repetition { Sequence { Terminal 'a', 'subrule' } }

The tables of rules given to the init() calls can have a human readable 'name' field, meant for diagnostics.

	Sequence { name = 'one a followed by many bees', Terminal { name = 'some terminal, 'a' }, Repetition { Terminal 'b' } }

The first level rules are put in a table and indexed by reference strings (that must match the ones used in the rules), passed to
Grammar:init() along with a string indicating the entry rule.
	
	rule_1 := 'A' { rule_2 } 'D'
	rule_2 := 'B' [ 'C' ] rule_1
	
	becomes
	
	g = {
		rule_1 = Sequence { name = 'the first rule', Terminal 'A', Repetition { 'rule_2' }, Terminal 'D' },
		rule_2 = Sequence { Terminal 'B', Optional { Terminal 'C' }, 'rule_1' }
	}

	grammar_object = Grammar(g,'rule_1')

When building the Grammar object, the grammar is checked for LL(1) validity. Conflicts are reported and execution stops immediately.

1. First/First conflict: in a Choice rule, two choices can start with the same token, making it impossible to choose between the two
2. First/Follow conflict: in a Sequence rule, a rightmost optional subrule starts with the same token as one that directly follows,
making it impossible to choose between applying the optional, or start the following rule.
3. First/Follow in repetition: a rightmost optional of the subrule starts with the same token as the whole rule, thus making it impossible
to choose between applying the optional, or starting a new occurence of the repetition. This is simply a wrapped-around application of point 2,
since a Repetition is equivalent to an infinite sequence of optionals of the subrule:

	{ rule } <=> [ rule [ rule [ rule [ rule [ rule ...

By "rightmost optional subrule" we mean a rule at any level of deepness that can end the considered rule, and by "directly follows" we mean that it
can appear right after (there can be optionals in between, or rules that can match an empty input). Thus Nova is capable of finding the
conflict with 'b' 'c' 'd' and 'e' in this example (assuming a correct implementation...):

	( 'a' [ 'b' { 'c' } [ 'e' ] ] ) [ 'b' ] ( 'c' | { 'd' } ) [ 'e' ] 'd'

Notes:
1. Left recursion is not tested and leads to stack overflow during parsing
2. When printing rules, the 'name' field is used when present. Otherwise, a pretty printing of the rule content is done.
Cyclic rule references without 'name' fields in any of the rules results in an infinite recursion.
3. Because of the current implementation, if the LL(1) validation is in fact broken, the following happens:
	a. in a Choice, the first subrule in the list whose first set contains the current token is parsed
	b. an Optional or Repetition is always parsed if its first set contains the current token

Possible shortcuts to use in grammar files:
local S = Sequence
local C = Choice
local T = Terminal
local R = Repetition
local O = Optional
local N = NamedRule

]]

----------
-- Rule --
----------

Rule = class()

function Rule:init()
	
	self.name = nil		-- a string used for context
	
	return self
end

function Rule:to_string()
	error('Override this')
end

function Rule:get_name()
	return self.name or self:to_string()
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

-- Get all the optionals from the left (start at 'start' in sequences), and the first non optional

function Rule:get_first_rules(start)
	error('Override this')
end

function Rule:validate()
	error('Override this')
end

-- Returns: success (bool), node, context requested when error (bool)

function Rule:parse(context)
	error('Override me')
end

function Rule:format_error(c)
	
	local expected = ""
	local count = 0
	for k,v in pairs(self:get_first_set()) do
		expected = expected .. "'" .. k .. "' "
		count = count + 1
	end
	expected = expected:sub(1,#expected-1)
	
	if count > 1 then
		expected = 'one of ' .. expected
	end
	
	c:adderror('error','failed to parse ' .. self:get_name() .. ': expected ' .. expected .. ', found \'' .. c:peek().value .. '\' instead', c:peek().pos)
	
	-- Rule reminder if it has a name
	if self.name then
		c:adderror('info', self.name .. ' := ' .. self:to_string())
	end
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
		
		if type(rule) == 'string' then
			
			if g.rules[rule] then
				self.rules[i] = g.rules[rule]
			else
				error('Rule:resolve_link() - unknown rule \'' .. rule .. '\'')
			end
		
		elseif rule.isa and rule:isa(Rule) then
			rule:resolve_links(g)
		else
			error('Rule:resolve_link() expects strings or Rule objects')
		end
		
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

function Sequence:get_first_rules(start)
	
	local set = {}
	
	for i = start,#self.rules do
		local v = self.rules[i]
		
		if v:isa(Optional) or v:isa(Repetition) then
			set[v] = true
		end
		
		if not v:is_epsilon() then
			set[v] = true
			break
		end
	end
	
	return set
end

function Sequence:validate()
	
	-- Use memoized if any
	if self.valid ~= nil then
		return self.valid
	end
	
	local valid = true
	
	-- Need to check that for any optional subrule (or that contains an optional at the end)
	-- that its first set doesn't collide with one of the following subrules
	
	for i = 1,#self.rules-1 do
		
		local lefts = self.rules[i]:get_rightmost_optionals()
		local rights = self:get_first_rules(i+1)
		
		for left,_ in pairs(lefts) do
			for right,_ in pairs(rights) do
			
				local inter = set_intersection(left:get_first_set(),right:get_first_set())
				
				if not set_empty(inter) then
					print('First/Follow conflict with ' .. left:get_name() .. ' and ' .. right:get_name()
						.. ' in ' .. self:get_name() )
					print('Shared tokens:')
					set_print(inter)
					valid = false
				end
				
			end
		end
		
	end
	
	-- Memoize
	self.valid = valid
	
	-- Recurse
	
	local ret = true
	
	for i,v in ipairs(self.rules) do
		if not v:validate() then
			ret = false
		end
	end
	
	return self.valid and ret
end

function Sequence:parse(c)
	
	local head = c:peek()
	local first = self:get_first_set()
	
	-- Is lookahead valid?
	
	if not first[head.kind] and not self:is_epsilon() then
	
		self:format_error(c)
		return false,nil,true
	end
	
	-- Yes, parse then
	
	local node = Node(self)
	
	for i,sub in ipairs(self.rules) do
		
		local succ,subnode,info = sub:parse(c)
		
		node.nodes[i] = subnode
		
		if not succ then
			if info and self.name then
				-- Give context
				c:adderror('info','in ' .. self:get_name() .. ' started here:', node:first())
				
				return false,node
			else
				-- Forward context request
				return false,node,info
			end
		end
		
	end
	
	-- Hey, success
	
	return true,node
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
		
		if type(rule) == 'string' then
			
			if g.rules[rule] then
				self.rules[i] = g.rules[rule]
			else
				error('Rule:resolve_link() - unknown rule \'' .. rule .. '\'')
			end
		
		elseif rule.isa and rule:isa(Rule) then
			rule:resolve_links(g)
		else
			error('Rule:resolve_link() expects strings or Rule objects')
		end
		
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

function Choice:get_first_rules(start)
	
	assert(start == 1)	-- Only sequences need to check themselves from the middle
	
	local set = {}
	
	for i,choice in ipairs(self.rules) do
		local opts = choice:get_first_rules(start)
		set = set_union(set,opts)
	end
	
	return set
end

function Choice:validate()
	
	if self.valid ~= nil then
		return self.valid
	end
	
	-- Need to check that no two choices have elements in common in their first sets
	
	local valid = true
	
	for i = 1,#self.rules-1 do
		for j = i+1,#self.rules do
			local inter = set_intersection(self.rules[i]:get_first_set(),self.rules[j]:get_first_set())
			
			if not set_empty(inter) then
				print('First/First conflict with ' .. self.rules[i]:get_name() .. ' and ' .. self.rules[j]:get_name()
					.. ' in ' .. self:get_name() )
				print('Common tokens: ')
				set_print(inter)
				valid = false
			end
		end
	end
	
	-- Memoize
	
	self.valid = valid
	
	-- Recurse
	
	local ret = true
	
	for i,v in ipairs(self.rules) do
		if not v:validate() then
			ret = false
		end
	end
	
	return self.valid and ret
end

function Choice:parse(c)
	
	local head = c:peek()
	local first = self:get_first_set()
	
	-- Is lookahead valid?
	
	if not first[head.kind] and not self:is_epsilon() then
	
		self:format_error(c)
		return false,nil,true
	end
	
	-- Yes, parse then
	
	for i,sub in ipairs(self.rules) do
		
		local first = sub:get_first_set()
		
		if first[head.kind] then
			local succ,subnode,info = sub:parse(c)
			
			if not succ then
				return false,subnode,info
			else
				return true,subnode
			end
		end
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

function Terminal:get_first_rules(start)
	return { [self] = true }
end

function Terminal:validate()
	return true
end

function Terminal:parse(c)
	
	local head = c:peek()
	
	if head.kind == self.token then
		
		local node = TerminalNode(self,head)
		c:consume()
		
		return true,node
	else
		
		local str = '\'' .. self.token .. '\'' .. c:format_opt()
		c:adderror('error','expected ' .. str .. ', found \'' .. head.value .. '\' instead', head.pos)
		
		return false,nil,true
	end
	
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
	
	if type(self.rule) == 'string' then
		
		if g.rules[self.rule] then
			self.rule = g.rules[self.rule]
		else
			error('Rule:resolve_link() - unknown rule \'' .. self.rule .. '\'')
		end
	
	elseif self.rule.isa and self.rule:isa(Rule) then
		self.rule:resolve_links(g)
	else
		error('Rule:resolve_link() expects strings or Rule objects')
	end
	
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

function Repetition:get_first_rules(start)
	
	assert(start == 1)
	
	return {[self] = true}
end

function Repetition:validate()
	
	-- Use memo
	
	if self.valid ~= nil then
		return self.valid
	end
	
	-- In the subrule, check the rightmost optionals with the first and possibly followings (loop around)
	
	local valid = true
	
	local lefts = self.rule:get_rightmost_optionals()
	
	-- Remove the whole rule, or it would always conflict with its first subrule
	lefts[self.rule] = nil
	
	local rights = self.rule:get_first_rules(1)
	
	for left,_ in pairs(lefts) do
		for right,_ in pairs(rights) do
			
			local inter = set_intersection(left:get_first_set(),right:get_first_set())
			
			if not set_empty(inter) then
				print('First/Follow conflict (in repetition) with ' .. left:get_name() .. ' and ' .. right:get_name()
					.. ' in ' .. self:get_name() )
				print('Shared tokens:')
				set_print(inter)
				valid = false
			end
		end
	end
	
	-- Memoize
	
	self.valid = valid
	
	-- Recurse
	return self.rule:validate() and self.valid
end

function Repetition:parse(c)
	
	local first = self.rule:get_first_set()
	local node = Node(self)
	
	while true do
	
		local head = c:peek()
		
		-- Is lookahead valid?
		if not first[head.kind] then
			
			if self.name then
				table.insert(c.last_opt,self)
			elseif self.rule:isa(Choice) then
				for i,sub in ipairs(self.rule.rules) do
					table.insert(c.last_opt,sub)
				end
			else
				table.insert(c.last_opt,self.rule)
			end
			
			-- And go on
			return true,node
		
		else
			local succ,subnode,info = self.rule:parse(c)
			
			if not succ then
				return false,node,info
			else
				table.insert(node.nodes,subnode)
			end
		end
	end
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
	
	if type(self.rule) == 'string' then
		
		if g.rules[self.rule] then
			self.rule = g.rules[self.rule]
		else
			error('Rule:resolve_link() - unknown rule \'' .. self.rule .. '\'')
		end
	
	elseif self.rule.isa and self.rule:isa(Rule) then
		self.rule:resolve_links(g)
	else
		error('Rule:resolve_link() expects strings or Rule objects')
	end
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

function Optional:get_first_rules(start)
	
	assert(start == 1)
	
	return {[self] = true}
end

function Optional:validate()
	return self.rule:validate()
end

function Optional:parse(c)
	
	local head = c:peek()
	local first = self:get_first_set()
	
	-- Is lookahead valid?
	
	if not first[head.kind] then
		
		-- Hey, it's OK, we're optional anyway
		-- Remember us
		
		if self.name then
			table.insert(c.last_opt,self)
		elseif self.rule:isa(Choice) then
			for i,sub in ipairs(self.rule.rules) do
				table.insert(c.last_opt,sub)
			end
		else
			table.insert(c.last_opt,self.rule)
		end
		
		-- And go on
		
		return true,EmptyNode(self)
	
	else
		
		-- Return directly the subrule's node
		
		return self.rule:parse(c)
	end
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
	
	if type(self.rule) == 'string' then
		
		if g.rules[self.rule] then
			self.rule = g.rules[self.rule]
		else
			error('Rule:resolve_link() - unknown rule \'' .. self.rule .. '\'')
		end
	
	elseif self.rule.isa and self.rule:isa(Rule) then
		self.rule:resolve_links(g)
	else
		error('Rule:resolve_link() expects strings or Rule objects')
	end
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

function NamedRule:add_rightmost_optionals(set)
	self.rule:add_rightmost_optionals(set)
end

function NamedRule:get_first_rules(start)
	return self.rule:get_first_rules(start)
end

function NamedRule:validate()
	return self.rule:validate()
end

function NamedRule:parse(c)
	
	local head = c:peek()
	local first = self:get_first_set()
	
	-- Is lookahead valid?
	
	if not first[head.kind] and not self:is_epsilon() then
		self:format_error(c)
		return false,nil,true
	end
	
	local succ,node,info = self.rule:parse(c)
	
	if succ then
		-- Take node as own
		node.rule = self
		return true,node
	else
		if info then
			-- Give context
			c:adderror('info','in ' .. self:get_name() .. ' started here:', node and node:first())
		end
		return false,node
	end
end

-------------
-- Grammar --
-------------

Grammar = class()

function Grammar:init(g,entry)
	
	self.rules = g
	
	self:validate()
	
	self.entry = self.rules[entry]
	if not self.entry then
		print('Unknown entry rule \'' .. entry .. '\', grammar is invalid')
		os.exit(1)
	end
	
	return self
end

function Grammar:validate()
	
	-- Use memo
	
	if self.valid ~= nil then
		return self.valid
	end
	
	-- Replace named rules by references
	
	for k,rule in pairs(self.rules) do
		rule:resolve_links(self)
	end
	
	self.valid = true
	
	for k,rule in pairs(self.rules) do
		if not rule:validate() then
			self.valid = false
		end
	end
	
	if not self.valid then
		print('Grammar is not valid')
		os.exit(1)
	end
	
	return self.valid
end

function Grammar:parse(context)
	
	local success,node = self.entry:parse(context)
	
	return success,node
end

----------
-- Node --
----------

-- There are actually only 2 types of nodes: sequences and terminals.
-- Indeed, to avoid a too deep parse tree, Choice, NamedRule and Optional
-- return directly the underlying node, and the result of a Repetition is a
-- list of nodes, which looks like a sequence.

-- We do use a bit a duck-typing here, no need for a bigger class with just
-- .rule in it...

Node = class()

function Node:init(rule)
	
	-- Reference to the rule that produced it
	self.rule = rule
	
	-- Subnodes
	self.nodes = {}
	
	return self
end

-- Returns a position object that encompasses subnodes from first to last
-- If first or last happen to be nil, get the closest ones

-- Defaults to the entire subtree

function Node:position(first,last)
	
	if #self.nodes == 0 then
		error('Empty node, that should nooooot happen')
	end
	
	if first > last then
		error('Invalid range')
	end
	
	local first = first or 1
	local last = last or #self.nodes
	
	while not self.nodes[first] do
		first = first + 1
	end
	
	while not self.nodes[last] do
		last = last - 1
	end
	
	return self.nodes[first]:position():range(self.nodes[last]:position())
end

-- Get the position of the first token in the node tree

function Node:first()
	
	if #self.nodes == 0 then
		error('Empty node, that should nooooot happen')
	end
	
	local first = first or 1
	
	while self.nodes[first]:isa(EmptyNode) do
		first = first + 1
	end
	
	return self.nodes[first]:first()
end

function Node:to_string(indent)
	
	local indent = indent or 0
	local s
	
	local indent_s = string.rep("| ",indent)
	
	s = indent_s .. self.rule:get_name() .. ': '
	
	-- Empty repetitions
	if #self.nodes == 0 then
		s = s .. '<empty>\n'
	
	-- Normal case
	else
		s = s .. '{\n'
		
		for i,v in ipairs(self.nodes) do
			s = s .. v:to_string(indent + 1)
		end
		
		s = s .. indent_s .. '}\n'
	end
	
	return s
end

------------------
-- TerminalNode --
------------------

TerminalNode = class()

function TerminalNode:init(rule,token)
	
	self.rule = rule
	self.token = token
	
	return self
end

function TerminalNode:position()
	return self.token.pos
end

function TerminalNode:first()
	return self.token.pos
end

function TerminalNode:to_string(indent)
	
	local indent = indent or 0
	local s
	
	local indent_s = string.rep("| ",indent)
	
	s = indent_s .. '\'' .. self.token.kind .. '\': \'' .. self.token.value .. '\'\n'
	
	return s
end

---------------
-- EmptyNode --
---------------

-- Used for filling in optionals and repetitions that parse nothing.
-- For implementation reasons, it's better to have something that nil.

EmptyNode = class()

function EmptyNode:init(rule)
	
	self.rule = rule
	
	return self
end

function EmptyNode:position()
	return nil
end

function EmptyNode:first()
	error('Should never be called')
end

function EmptyNode:to_string(indent)
	
	local indent = indent or 0
	local s
	
	local indent_s = string.rep("| ",indent)
	
	s = indent_s .. self.rule:get_name() .. ': ' .. '<empty>\n'
	
	return s
end

---------------------
-- Parsing context --
---------------------

ParsingContext = class()

function ParsingContext:init(tokens)
	
	-- Tokens
	
	self.tokens = tokens
	self.current = 1		-- the current look ahead. Number of parsed token is "current-1"
	
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
		
		if opt:isa(Sequence) and not opt.name then
			str = str .. '( ' .. opt:get_name() .. ' )'
		else
			str = str .. opt:get_name()
		end
	end
	
	return str
end

function ParsingContext:adderror(typ,mess,pos)

	local err = {'Parser', typ, mess, pos}
	table.insert(self.errors,err)
end

---------------
-- Utilities --
---------------

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

SoolGrammar = dofile 'sool_grammar.lua'

function parse(tokens)
	
	local context = ParsingContext(tokens)
	
	local success,node = SoolGrammar:parse(context)
	print(success)
	if node then print(node:to_string()) end
	print''
	
	return context.errors,node
end
