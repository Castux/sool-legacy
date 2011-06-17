require 'nova'

local g = require 'sool_grammar'

function parse(tokens)
	
	local context = nova.new_context(tokens,g)
	
	local success,node = context.parse()
	
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
			io.write(indent, nova.rule_name(t.rule), ': <empty>\n')
		elseif #t == 1 and t[1].token then
			print_tree(t[1],lev)
		else
			io.write(indent, nova.rule_name(t.rule), ': {\n')
			
			for i,v in ipairs(t) do
				print_tree(v,lev+1)
			end
			io.write(indent,'}\n')
		end
	end
end
