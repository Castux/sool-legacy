--[[

Token structure:
================

1 = type (Name, ClassName, Symbol, Number, or complete string for others)
2 = value (string of original text)
3 = position in file
token = true

Position structure:
===================

fline,fcol = beginning of token
lline,lcol = end of token

Only strings can be multiline, but this structure is the same as in
nodes in the parse tree.

Error structure:
================

1 = origin (Lexer, Parser, Analyser...)
2 = type (Error, Warning, Info)
3 = message
4 = position in file

]]

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
		col = 1
		index = index + 1
		line = line + 1
	end
	
	local function lexerr()
		local err = {
			"Lexer",
			"error",
			"unexpected symbol '" .. s:sub(index,index) .. "'",
			{
				fline = line,
				lline = line,
				fcol = col,
				lcol = col
			}
		}
		local info = {
			"Lexer",
			"info",
			"valid symbols at token beginning are: [_a-zA-Z0-9@] and operators [~+-*/%^|#=<>:.,;()[]{}\"'"
		}
		return nil,{err,info}
	end
	
	local function addtok(val,typ)
		local typ = typ or val
		local tok = {
			typ,
			val,
			{
				fline=line,
				lline=line,
				fcol=col,
				lcol=(col + #val - 1)
			},
			token = true
		}
		
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
		
		-- Special punctuation
		m = s:match("^[~%+%-%*/%%^|#=<>:.,;%(%)%[%]{}\"']",index)
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
	
	-- add end mark
	local tok = {
		'EOF',
		'EOF',
		{
			fline=line,
			lline=line,
			fcol=col,
			lcol=col
		}
	}
	
	tokens[#tokens+1] = tok
	
	return tokens
end
