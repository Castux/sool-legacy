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
	
	-- Replace named rules by references, and terminal strings by terminal tables
	
	for k,rule in pairs(g) do
		resolve_links(rule,g)
	end
	
	local ret = true
	
	for k,rule in pairs(g) do
		if not validate_rule(rule,g) then
			ret = false
		end
	end
	
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
						print('First/Follow conflict with ' .. ( opt.name or rule_to_string(opt) ) .. ' and ' .. ( r[j].name or rule_to_string(r[j]) ) 
							.. ' in ' .. (r.name or rule_to_string(r) ) )
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
						print('First/Follow conflict (in repetition) with ' .. ( opt.name or rule_to_string(opt) ) .. ' and ' .. ( r[j].name or rule_to_string(r[j]) ) 
							.. ' in ' .. (r.name or rule_to_string(r) ) )
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
					print('First/First conflict with ' .. ( r[i].name or rule_to_string(r[i]) ) .. ' and ' .. ( r[j].name or rule_to_string(r[j]) ) 
						.. ' in ' .. (r.name or rule_to_string(r) ) )
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
