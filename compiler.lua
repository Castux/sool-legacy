require 'lexer'
require 'parser'
require 'analyzer'

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

function print_error(err)
	
	-- Retrieve file info from position structure, if any
	local file = err[4] and err[4].file or nil
	
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
		
		io.write(Cd(file.name,5),':')
		
		if fline == lline then
			io.write(Cd(fline,2),': ')
		else
			io.write(Cd(err[4].fline .. '-' .. err[4].lline,2),': ')
		end
	end
	
	io.write(err[3],'\n')
	
	if file then
		local str = ""
		local fline,lline = err[4].fline,err[4].lline
		local fcol,lcol = err[4].fcol,err[4].lcol
		
		str = file[fline]:sub(1,fcol-1)
		
		if fline == lline then
			str = str .. C(file[fline]:sub(fcol,lcol),col)
			str = str .. file[fline]:sub(lcol+1,-1)
			str = str .. '\n'
			
			local count = 1
			local marks = file[fline] .. "="	-- special end char for EOF
			marks = marks:gsub(".",function(s)
				if s == '\t' then
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
			
			str = str .. Cd(marks,col) .. '\n'
		
		else
			local colored = file[fline]:sub(fcol,-1) .. '\n'
			
			for i = fline+1,lline-1 do
				colored = colored .. file[i] .. '\n̈́'
			end
			
			colored = colored .. file[lline]:sub(1,lcol)
			str = str .. C(colored,col) .. file[lline]:sub(lcol+1,-1) .. '\n'
		end
		
		io.write(str)
	end
end

-- Treat file up to parsing

function parse_file(file)
	
	-- Lexing
	
	local tokens,err = lex(file)
	
	if err then
		for i,v in ipairs(err) do
			print_error(v,file)
		end
		return
	end
		
	-- Check that file wasn't empty
	if #tokens-1 == 0 then		-- do not count EOF
		print_error{
			'Lexer',
			'warning',
			'no tokens found in file ' .. Cd(file.name,5)
		}
	else
		print_error {
			'Compiler',
			'info',
			'successfully lexed file '.. Cd(file.name,5) ..
			' for a total of ' .. #tokens-1 .. ' tokens'
		}
	end
	
	-- Parsing
	
	local chunk,err = parse(tokens)
	
	local errcount = 0
	
	for i,v in ipairs(err) do
		print_error(v,file)
		if v[2] == 'error' then
			errcount = errcount + 1
		end
	end
	
	local mess
	if errcount > 0 then
		mess = 'parser reported ' .. errcount .. ' error' .. (errcount > 1 and 's' or '')
	else
		mess = 'successfully parsed file ' .. Cd(file.name,5)
	end
	
	print_error {'Compiler','info',mess}
	
	if errcount > 0 then
		return
	end
	
	return chunk
end

-- Compile a list of files together

function compile(list)
	
	-- Load them all
	
	local files = {}
	
	for i,path in ipairs(list) do
		
		local file,err = load_file(path)
		
		if err then
			print_error(err)
			os.exit(1)
		end
		
		table.insert(files,file)
	end
	
	-- Parse them all
	
	local chunks = {}
	
	for i,file in ipairs(files) do
	
		local chunk = parse_file(file)
		
		if not chunk then
			os.exit(1)
		end
		
		table.insert(chunks,chunk)
	end
	
	-- Merge lists of classes into single chunk
	
	local chunk = chunks[1]
	
	for i = 2,#chunks do
		for _,class in ipairs(chunks[i].classes) do
			table.insert(chunk.classes,class)
			class.parent = chunk
		end
	end
	
	chunks = nil
	
	-- Launch analysis
	
	local errors = validate(chunk)
	
	local errcount,warncount = 0,0
	for i,err in ipairs(errors) do
		print_error(err)
		if err[2] == 'error' then
			errcount = errcount + 1
		elseif err[2] == 'warning' then
			warncount = warncount + 1
		end
	end
	
	local mess
	if errcount > 0 then
		mess = 'analyzer reported ' .. errcount .. ' error' .. (errcount ~= 1 and 's' or '') ..
		' and ' .. warncount .. ' warning' .. (warncount ~= 1 and 's' or '')
	else
		mess = 'chunk passed validation, for a total of ' .. #chunk.classes .. ' classes'
	end
	
	print_error {'Compiler','info',mess}
	
	if errcount > 0 then
		os.exit(1)
	end
end
