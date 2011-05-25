module(..., package.seeall)

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
			s = k.name or ('[[' .. rule_to_string(k) .. ']]')
		end
		table.insert(t,s)
	end
	
	print('{' .. table.concat(t,' ') .. '}')
end

-------------------------
-- Grammar preparation --
-------------------------

function resolve_links(rule,g)
	
	for i,sub in ipairs(rule) do
		
		if type(sub) == 'string' then
		
			-- Named rule
			if g[sub] then
				rule[i] = g[sub]
				
			-- Terminal
			else
				rule[i] = { terminal = true, sub }
			end
		
		elseif type(sub) == 'table' then
			
			resolve_links(sub,g)
		
		else
			error('Rule is neither a string or a table: ' .. type(r))
		end
		
	end
	
end

function validate_grammar(g)
	
	-- Don't do it twice
	
	if g.valid then
		return true
	end
	
	-- Replace named rules by references, and terminal strings by terminal tables
	
	for k,rule in pairs(g) do
		if k ~= 'nova_entry' then
			resolve_links(rule,g)
		end
	end
	
	local ret = true
	
	for k,rule in pairs(g) do
		if not validate_rule(rule,g) then
			ret = false
		end
	end
	
	g.valid = true
	
	return ret
end


function first_set(r)
	
	local first = {}
	
	-- Terminal
	if r.terminal then
		first[r[1]] = true
		return first
	end
	
	-- Table, do the work
	
	-- Use memoized if any
	if r.first_set then
		return r.first_set
	end
	
	-- Empty sequence
	if #r == 0 then
		return {}
	end
	
	-- Simple: sequence
	if not r.choice then
	
		first = first_set(r[1])
		
		-- For each consecutive espilon rule we need to add the ones that follow
		for i = 1,#r-1 do
			
			if not is_epsilon(r[i]) then
				break
			end
			
			local follow = first_set(r[i+1])
			first = set_union(first,follow)
		end
		
		
	-- Choice: merge sets for all choices
	else
		
		first = first_set(r[1])
		
		for i = 2,#r do
			
			local follow = first_set(r[i])
			first = set_union(first,follow)
		end
		
	end
	
	-- Memoize
	r.first_set = first
	
	return first
end

function is_epsilon(r)
	
	if r.optional or r.repetition then
		return true
	end
	
	if r.terminal then
		return false
	end
	
	-- Memo?
	if r.epsilon then
		return r.epsilon
	end
	
	local ret
	
	-- For choice, if any can generate empty string, we can
	if r.choice then
		
		ret = false
		
		for i,v in ipairs(r) do
			if is_epsilon(v) then
				ret = true
				break
			end
		end
		
	-- For sequence, they must all be able to generate it
	else
		
		local seq = true
		
		for i,v in ipairs(r) do
			if not is_epsilon(v) then
				seq = false
				break
			end
		end
		
		ret = seq
	end
	
	-- Memoize
	r.epsilon = ret
	
	return ret
end

function rule_to_string(r)
	
	if r.terminal then
		return "'" .. r[1] .. "'"
	end
	
	local str
	local t = {}
	
	for i,v in ipairs(r) do
		
		if v.name then
			table.insert(t,'"' .. v.name .. '"')
		else
			local sub = rule_to_string(v)
			if #v > 1 and not r.choice and not v.repetition and not v.optional then
				sub = '( ' .. sub .. ' )'
			end
			table.insert(t,sub)
		end
		
	end

	if not r.choice then
		str = table.concat(t,' ')
	else
		str = table.concat(t,' | ')
	end
	
	if r.repetition then
		str = '{ ' .. str .. ' }'
	end
	
	if r.optional then
		str = '[ ' .. str .. ' ]'
	end
	
	return str
end

function rule_name(r)
	
	return r.name or rule_to_string(r)
	
end

function get_rightmost_optionals(r)
	
	local function rec(r,set)
		-- Avoid infinite recursion
		if set[r] ~= nil then
			return
		end
		
		if r.optional or r.repetition then
			set[r] = true
		else
			set[r] = false						-- prevents recursion and still does not belong to set
		end
		
		if r.terminal then
			return
		end
		
		-- At any level of recursion, we need the subrules that end the rule and are optional
		
		-- Choice
		if r.choice then
			for i,v in ipairs(r) do
				rec(v,set)
			end
		
		-- Sequence
		else
			rec(r[#r],set)
			
			-- Must add rules from right to left if the final ones are consecutive epsilons
			local j = #r
			while is_epsilon(r[j]) and j > 1 do
				rec(r[j-1],set)
				j = j-1
			end
			
		end
	end
	
	-- Call it on empty set
	local set = {}
	rec(r,set)
	
	-- Clean up
	local res = {}
	for k,v in pairs(set) do
		if v then
			res[k] = true
		end
	end
	
	return res
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
		
		-- Need to check that for any optional subrule (or that contains an optional at the end),
		-- its first set doesn't collide with the one of the following subrules
		
		for i = 1,#r-1 do
			
			local optionals = get_rightmost_optionals(r[i])
			
			for opt,_ in pairs(optionals) do
			
				local j = i+1
				
				while true do
					local inter = set_intersection(first_set(opt),first_set(r[j]))
					
					if not set_empty(inter) then
						print('First/Follow conflict with ' .. rule_name(opt) .. ' and ' .. rule_name(r[j])
							.. ' in ' .. rule_name(r) )
						print('Shared tokens:')
						set_print(inter)
						ret = false
					end
					
					-- Go through all following epsilons
					if is_epsilon(r[j]) then
						j = j+1
						if j > #r then
							break
						end
					else
						break
					end
				end
			end
			
		end
		
		-- And if it's a repetition, check also the rightmost optionals with the first and possibly followings (loop around)
		
		if r.repetition then
			
			local optionals = get_rightmost_optionals(r)
			
			-- Remove the whole rule, or it would always conflict with its first subrule
			optionals[r] = nil
			
			for opt,_ in pairs(optionals) do
			
				local j = 1
				
				while true do
					local inter = set_intersection(first_set(opt),first_set(r[j]))
					
					if not set_empty(inter) then
						print('First/Follow conflict (in repetition) with ' .. rule_name(opt) .. ' and ' .. rule_name(r[j])
							.. ' in ' .. rule_name(r) )
						print('Shared tokens:')
						set_print(inter)
						ret = false
					end
					
					if is_epsilon(r[j]) then
						j = j+1
						if j > #r then
							break
						end
					else
						break
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

---------------------
-- Parsing context --
---------------------

-- Tokens are expected to be tables with a string as first element, value as second, and position as third

function new_context(tokens,grammar)
	
	local c = {}
	
	c.tokens = tokens
	c.current = 1		-- the current look ahead. Number of parsed token is "current-1"
	
	c.grammar = grammar
	
	c.errors = {}
	
	-- Init
	
	if not grammar.valid then
		if not validate_grammar(grammar) then
			os.exit(1)
		end
	end
	
	-- Methods (use table as upvalue)
	
	function c.consume()
		c.current = c.current + 1
	end
	
	function c.peek()
		return c.tokens[c.current]
	end

	function c.expect(tok,node)
		
		local head = c.peek()
		
		if head[1] == tok then
			table.insert(node,head)
			c.consume()
			return true
		else
			c.adderror('error','expected \'' .. tok .. '\', found \'' .. head[1] .. '\' instead', head[3])
			return false
		end
	end

	function c.adderror(typ,mess,pos)
		
		local err = {'Parser', typ, mess, pos}
		
		table.insert(c.errors,err)
		
	end
	
	function c.parse()
		return c.parse_rule(c.grammar.nova_entry)
	end
	
	-- Returns true and the node if success, returns false otherwise
	function c.parse_rule(r)
		
		local nodes = {}
		nodes.rule = r
		
		local node = {}
		node.rule = r
		
		-- Terminal
		if r.terminal then
			
			if not c.expect(r[1],node) then
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
			local head = c.peek()
			if not first[head[1]] then
				
				-- It's ok, return success and the node how it is now (empty for optional, with the already parsed things for repetition)
				if is_epsilon(r) then
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
					
					c.adderror('error','failed to parse ' .. rule_name(r) .. ': expected ' .. expected .. ', found \'' .. head[1] .. '\' instead', head[3])
					
					-- Rule reminder if it has a name. Also, if it contains only one subrule, it's probably a "context" name, so put the inside rule instead
					if r.name then
						c.adderror('info', r.name .. ' := ' .. rule_to_string( #r == 1 and r[1] or r ))
					end
					
					return false,retnode(),true
				end
			
			end
			
			-- Sequence
			if not r.choice then
				
				for i,sub in ipairs(r) do
					
					local succ,subnode,info = c.parse_rule(sub)
					
					table.insert(node,subnode)
					
					if not succ then
						if info and r.name then
							-- Give context
							c.adderror('info','in ' .. rule_name(r) .. ' started here:', node_start(node))
							
							return false,retnode()
						end
						
						return false,retnode(),info
					end
					
				end
				
			-- Choice
			else
				
				for i,sub in ipairs(r) do
					
					local first = first_set(sub)
					
					if first[head[1]] then
						local succ,subnode,no_info = c.parse_rule(sub)
						
						if not succ then
							return false,retnode(),no_info
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
	
	
	return c
end

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
	
	if n.token then
		return n[3]
	else
		for i = #n,1,-1 do
			if #n[i] > 0 then
				return node_start(n[i])
			end
		end
	end
	
end

-- Position range, with two full positions
function range(from,to)
	local fline,fcol = from.fline,from.fcol
	local lline,lcol = to.lline,to.lcol
	
	-- from and to should really be in the same file
	assert(from.file == to.file)
	local file = from.file
	
	return {fline = fline, lline = lline, fcol = fcol, lcol = lcol, file = file}
end

function node_pos(n)
	return range(node_start(n),node_end(n))
end
