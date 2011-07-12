require 'class'

-----------
-- Token --
-----------

Token = class()

function Token:init(kind,value,pos)
	
	self.kind = kind or ''		-- Name, ClassName, Symbol, Number, String, or complete keyword
	self.value = value or ''	-- String of original text
	self.pos = pos or nil		-- Reference to position
	
	return self
end

--------------
-- Position --
--------------

Position = class()

function Position:init(fline,fcol,lline,lcol,file)
	
	self.fline = fline
	self.fcol = fcol
	self.lline = lline
	self.lcol = lcol
	self.file = file
	
	return self
end

function Position:range(to)
	
	-- destination should really be in the same file
	assert(self.file == to.file)
	
	return Position(self.fline,self.fcol,to.lline,to.lcol,self.file)
end

--[[

Error structure:
================

1 = origin (Lexer, Parser, Analyser...)
2 = type (error, warning, info)
3 = message
4 = position in file

]]

lex = function(file)
	
	local s = file.all
	
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
			Position(line,col,line,col,file)
		}
		local info = {
			"Lexer",
			"info",
			"valid symbols at token beginning are: [_a-zA-Z0-9@'\"] and operators [ ~+-*/%^|#=<>:.,;()[]{} ] - BULLSHIT FIXME"
		}
		return nil,{err,info}
	end
	
	local function addtok(val,typ)
		local typ = typ or val
		local tok = Token(
			typ,
			val,
			Position(line,col,line,col + #val - 1,file)
		)
		
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
		
		-- Digraphs
		local digr = {'<=','>=','==','~='}
		local wasdigr = false
		
		for i,v in ipairs(digr) do
			m = s:match("^" .. v,index)
			if m then
				wasdigr = true
				break
			end
		end
		
		if wasdigr then
			addtok(m)
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
		
		-- Special punctuation
		m = s:match("^[~%+%-%*/%%^|&=<>:.,;%(%)%[%]{}#\\]",index)
		if m then
			addtok(m)
			break
		end
		
		-- Name
		m = s:match("^[_a-z][_a-zA-Z0-9]*[%?!]?",index)
		if m then
			
			-- Reserved name?
			local res = {'class', 'meth', 'end', 'num', 'vec', 'str',
			'return', 'do', 'if', 'then', 'elseif', 'else', 'while',
			'for', 'in', 'break', 'skip', 'nil', 'false', 'true',
			'private', 'op', 'and', 'or', 'xor', 'not', 'as', 'sym'}
			
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
		
		-- String
		if s:sub(index,index) == "'" or s:sub(index,index) == '"' then
			m = s:match("^''",index) or s:match('^""',index) or
			s:match("^'.-[^\\]'",index) or s:match('^".-[^\\]"',index)
			if m then
				
				local fline,fcol = line,col
				
				-- count newlines
				local _,nl = m:gsub('\n',{})
				
				line = line + nl
				
				if nl > 0 then
					-- count characters on last line
					local rem = m:match("[^\n]*$")
					col = #rem + 1
				else
					-- single line, basic advance
					col = col + #m
				end
				
				-- update global index
				index = index + #m
				
				-- form token
				local tok = Token(
					m:sub(1,1) == '"' and 'String' or 'Symbol',
					m,
					Position(fline,fcol,line,col,file)
				)

				tokens[#tokens+1] = tok
			
			else
				local err = {
					"Lexer",
					"error",
					"unfinished string/symbol starting at",
					Position(line,col,line,col,file)
				}
				
				return nil,{err}
			end
		end
		
		-- If all else fails...
		if not m then
			return lexerr()
		end
	end
	end
	
	-- add end mark
	local tok = Token(
		'EOF',
		'EOF',
		Position(line,col,line,col,file)
	)
	
	tokens[#tokens+1] = tok
	
	return tokens
end
