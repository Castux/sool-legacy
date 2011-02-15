require 'lexer'
require 'parser'

--[[
File structure
==============

name = path or name
all = complete content
1,2,... = lines
]]

function load_file(path)

	local fp = io.open(path,"r")
	if not fp then
		local err = {
			"Compiler",
			"error",
			"could not open file " .. path
		}
		
		return nil,err
	end
	
	local file = { name = path }
	
	-- Read content
	file.all = fp:read("*a")
	
	-- Split into lines
	local count = 1
	
	for line in file.all:gmatch "(.-)\n" do
		file[count] = line
		count = count + 1
	end
	
	return file
end

function print_error(err,file)
	
	io.write(err[1],' ')
	
	local col
	if err[2] == 'error' then
		col = "\027[1;31m"
	elseif err[2] == 'warning' then
		col = "\027[1;33m"
	elseif err[2] == 'info' then
		col = "\027[1;34m"
	end
	
	io.write(col,err[2],"\027[0m",': ')
	
	if file then
		local fline,lline = err[4].fline,err[4].lline
		
		if fline == lline then
			io.write(file.name,':',"\027[1;35m",fline,"\027[0m",': ')
		else
			io.write(file.name,':',"\027[1;35m",err[4].fline,'-',err[4].lline,"\027[0m",': ')
		end
	end
	
	io.write(err[3],'\n')
	
	if file then
		local str = ""
		local fline,lline = err[4].fline,err[4].lline
		local fcol,lcol = err[4].fcol,err[4].lcol
		
		str = file[fline]:sub(1,fcol-1)
		str = str .. "\027[1;31m"
		
		if fline == lline then
			str = str .. file[fline]:sub(fcol,lcol)
			str = str .. "\027[0m"
			str = str .. file[fline]:sub(lcol+1,-1)
			str = str .. '\n'
			
			str = str .. "\027[1;32m"
			
			local count = 1
			local marks = file[fline] .. "="	-- special end char for EOF
			marks = marks:gsub(".",function(s)
				if s == '\t' or s == ' ' then
					count = count + 1
					return s
				end
				
				if count >= fcol and count <= lcol then
					count = count + 1
					return '^'
				end
				
				count = count + 1
				return ' '
			end)
			
			str = str .. marks .. "\027[0m\n"
		
		else
			str = str .. file[fline]:sub(fcol,-1) .. '\n'
			
			for i = fline+1,lline-1 do
				str = str .. file[i] .. '\n̈́'
			end
			
			str = str .. file[lline]:sub(1,lcol)
			str = str .. "\027[0m"
			str = str .. file[lline]:sub(lcol+1,-1)
		end
		
		io.write(str,'\n')
	end
end


function compile(path)
	
	-- Loading
	
	local file,err = load_file(path)

	if err then
		print_error(err)
		return
	end
	
	-- Lexing
	
	local tokens,err = lex(file.all)
	
	if err then
		print_error(err,file)
		return
	else
		local err = {
			"Compiler",
			"info",
			"successfully lexed file ".. file.name
		}
		print_error(err)
	end
	
	pp(tokens)
	print''
	print'=========='
	
	-- Parsing
	
	local tree,err = parse(tokens)
	
	for i,v in ipairs(err) do
		print_error(v,file)
	end
	
end
