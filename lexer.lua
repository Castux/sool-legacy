lex = function(s)

	local line = 1
	local col = 1
	local index = 1
	
	local tokens = {}
	
	local function adv(n)
		col = col + n
		index = index + n
	end
	
	local function newline()
		col = 0
		index = index + 1
		line = line + 1
	end
	
	local function lexerr()
		return {("Lexing error at " .. line .. ":" .. col), tokens}
	end
	
	local function addtok(val,typ)
		local typ = typ or val
		local tok = {typ,val,line=line,start=col,fin=(col + #val - 1)}
		
		tokens[#tokens+1] = tok
		
		adv(#val)
	end
	
	while index < #s do
	while true do
		local m
		
		-- Skip horizontal white space
		m = s:match("^[\t ]+",index)
		if m then
			adv(#m)
			break
		end
		
		-- Remove comment
		m = s:match("^%-%-[^\n]*",index)
		if m then
			adv(#m)
			break
		end
		
		-- End of line/empty line
		m = s:match("^\n",index)
		if m then
			newline()
			break
		end
		
		-- Special puncutation
		m = s:match("^[~%+%-%*/%%^|#=<>:.,;%(%)%[%]{}]",index)
		if m then
			addtok(m)
			break
		end
		
		-- Name
		m = s:match("^[_a-z][_a-zA-Z0-9]*[%?!]?",index)
		if m then
			
			-- Reserved name?
			local res = {'class', 'methods', 'end', 'num', 'vec', 'str',
			'return', 'do', 'if', 'then', 'elseif', 'else', 'while',
			'for', 'in', 'break', 'continue', 'nil', 'false', 'true',
			'private', 'op', 'and', 'or', 'xor'}
			
			local wasres = false
			for i,v in ipairs(res) do
				if m == v then
					addtok(m)
					wasres = true
					break
				end
			end
			
			if not wasres then
				addtok(m,'Name')
			end
			
			break
		end
		
		-- ClassName
		m = s:match("^[A-Z][_a-zA-Z0-9]*",index)
		if m then
			addtok(m,'ClassName')
			break
		end
		
		-- Symbol
		m = s:match("^@(%S+)",index)
		if m then
			adv(1)	-- @
			addtok(m,'Symbol')
			break
		end
		
		-- Hex number
		m = s:match("^0[xX]%x+",index)
		if m then
			addtok(m,'Number')
			break
		end
		
		-- Number with dot
		m = s:match("^%d+%.%d+",index)
		if m then
			local expo = s:match("^[eE]%d+",index+#m)
			addtok(m .. (expo or ""),'Number')
			break
		end
		
		-- Number without dot
		m = s:match("^%d+",index)
		if m then
			local expo = s:match("^[eE]%d+",index+#m)
			addtok(m .. (expo or ""),'Number')
			break
		end
		
		-- If all else fails...
		if not m then
			return lexerr()
		end
	end
	end
	
	return tokens
end
