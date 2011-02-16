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

-- Enclose string in ANSI escape sequences
local function C(str,col)
	return "\027[1;" .. 30 + col .. "m" .. str .. "\027[0m"
end
local function Cd(str,col)
	return "\027[" .. 30 + col .. "m" .. str .. "\027[0m"
end

function print_error(err,file)
	
	local file = err[4] and file or nil
	
	io.write(err[1],' ')
	
	local col
	if err[2] == 'error' then
		col = 1
	elseif err[2] == 'warning' then
		col = 3
	elseif err[2] == 'info' then
		col = 4
	end
	
	io.write(C(err[2],col),': ')
	
	if file then
		local fline,lline = err[4].fline,err[4].lline
		
		io.write(Cd(file.name,2),':')
		
		if fline == lline then
			io.write(Cd(fline,5),': ')
		else
			io.write(Cd(err[4].fline .. '-' .. err[4].lline,5),': ')
		end
	end
	
	io.write(err[3],'\n')
	
	if file then
		local str = ""
		local fline,lline = err[4].fline,err[4].lline
		local fcol,lcol = err[4].fcol,err[4].lcol
		
		str = file[fline]:sub(1,fcol-1)
		
		if fline == lline then
			str = str .. C(file[fline]:sub(fcol,lcol),1)
			str = str .. file[fline]:sub(lcol+1,-1)
			str = str .. '\n'
			
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
			
			str = str .. C(marks,2) .. '\n'
		
		else
			local colored = file[fline]:sub(fcol,-1) .. '\n'
			
			for i = fline+1,lline-1 do
				colored = colored .. file[i] .. '\n̈́'
			end
			
			colored = colored .. file[lline]:sub(1,lcol)
			str = str .. C(colored,1) .. file[lline]:sub(lcol+1,-1) .. '\n'
		end
		
		io.write(str)
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
		for i,v in ipairs(err) do
			print_error(v,file)
		end
		return
	else
		local err = {
			"Compiler",
			"info",
			"successfully lexed file ".. Cd(file.name,2) ..
				" for a total of " .. #tokens-1 .. " tokens"	-- do not count EOF
		}	
		print_error(err)
	end
	
	-- Parsing
	
	local tree,err = parse(tokens)
	
	for i,v in ipairs(err) do
		print_error(v,file)
	end
	
end
