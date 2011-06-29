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

-- Get all the optionals from the left (start at 'start' in sequences), and the first non optional

function Rule:get_first_rules(start)
	error('Override this')
end

function Rule:validate()
	error('Override this')
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

function Grammar:parse(tokens)
	
	local c = ParsingContext(tokens)
	
	local success,node = self.entry:parse(c)
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

SoolGrammar = dofile 'sool_grammar.lua'

function parse(tokens)
	
	local context = ParsingContext(tokens,SoolGrammar)
	
	--local success,node = context:parse()
	
	--print_tree(node)
	--print''
	
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
