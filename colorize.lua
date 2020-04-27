#!/usr/bin/env lua
if arg[2] and arg[2]~='-' then
	io.output(arg[2])
end

local unpack=table.unpack or unpack
local floor=math.floor
local insert, remove=table.insert, table.remove
local byte, char=string.byte, string.char

local function readfile(file, bin)
	if file=='-' then
		return io.read '*a'
	else
		local mode=bin and 'rb' or 'r'
		local fd, err=io.open(file, mode)
		if not fd then
			error(err, 2)
		end
		local cnt=fd:read '*a'
		if not cnt then
			error("Failed to read file", 2)
		end
		fd:close()
		return cnt
	end
end


local NAME="([%w_]+)"
local VNAME="(%$%-?[%w_]+)"
local SNAME="(%@[%w_]+)"
local FNAME="([%w._-]+)"
local SEP="[;,%s]"
local OSEP=SEP..'?'
local NUM="(%d+)"
local DSTR, SSTR, BSTR="\"(.-)\"", "'(.-)'", "%[%[(.-)%]%]"

local variables={}
local colors={}
local gradients={}
local gradients2d={}

setmetatable(variables, {
	__index=function(self, name)
		if name:match('^$'..NUM) then
			return tonumber(name:sub(2, -1))
		end
	end,
	__newindex=function(self, name, val)
		if name:match('^$'..NUM) then
			error("Attempt to assign to number "..name, 2)
		elseif name:match('^$%-') then
			error("Attempt to assign to negative variable "..name, 2)
		end
		rawset(self, name, val)
	end
})

local function colorize(bg, r, g, b)
	return string.char(27)..'['..(bg and '4' or '3')..'8;2;'..tostring(r)..';'..tostring(g)..';'..tostring(b)..'m'
end
local function calcgradient(pct, r1, g1, b1, r2, g2, b2)
	if pct<0 or pct>100 then
		error("Gradient percent "..tostring(pct).." is out of bounds", 2)
	end
return
		floor((r1*(100-pct)+r2*pct)/100),
		floor((g1*(100-pct)+g2*pct)/100),
		floor((b1*(100-pct)+b2*pct)/100)
end
local function calcgradient2d(x, y, gr1, gr2)
	local r1, g1, b1=calcgradient(x, unpack(gr1))
	local r2, g2, b2=calcgradient(x, unpack(gr2))
	return calcgradient(y, r1, g1, b1, r2, g2, b2)
end

local function getvar(name)
	if name:match '^$%-' then
		return -getvar('$'..name:sub(3, -1))
	end
	return variables[name] or error("Variable "..name.." not declared", 2)
end
local function getcolor(name)
	return colors[name] or error("Color "..name.." not declared", 2)
end
local function getgradient(name)
	return gradients[name] or error("Gradient "..name.." not declared", 2)
end
local function getgradient2d(name)
	return gradients2d[name] or error("2D gradient "..name.." not declared", 2)
end

local stream={
	-- define variables
	{ -- from number
		{VNAME, '=', NUM},
		function(name, val)
			variables[name]=tonumber(val)
		end
	},
	{ -- from variable
		{VNAME, '=', VNAME},
		function(name, other)
			variables[name]=getvar(other)
		end
	},
	{ -- from color
		{VNAME, OSEP, VNAME, OSEP, VNAME, '=', NAME},
		function(rv, gv, bv, name)
			variables[rv], variables[gv], variables[bv]=unpack(getcolor(name))
		end
	},
	{ -- from string length
		{VNAME, '=', '#', SNAME},
		function(lh, rh)
			variables[lh]=#getvar(rh)
		end
	},
	{ -- from first byte of string
		{VNAME, '=', 'b', SNAME},
		function(lh, rh)
			variables[lh]=byte(getvar(rh))
		end
	},

	-- define strings
	{ -- from double-quoted string
		{SNAME, '=', DSTR},
		function(name, val)
			variables[name]=val
		end
	},
	{ -- from single-quoted string
		{SNAME, '=', SSTR},
		function(name, val)
			variables[name]=val
		end
	},
	{ -- from bracket-quoted string
		{SNAME, '=', BSTR},
		function(name, val)
			variables[name]=val
		end
	},
	{ -- from string
		{SNAME, '=', SNAME},
		function(lh, rh)
			variables[lh]=getvar(rh)
		end
	},
	{ -- from char value of variable
		{SNAME, '=', 'b', VNAME},
		function(lh, rh)
			local iv=getvar(rh)
			if iv<0 or iv>255 then
				error("Char value "..tostring(rh).." out of bounds")
			end
			variables[lh]=char(iv)
		end
	},

	-- arithmetic
	{ -- sum
		{VNAME, '=', VNAME, '%+', VNAME},
		function(name, lh, rh)
			variables[name]=getvar(lh)+getvar(rh)
		end,
	},
	{ -- subtraction
		{VNAME, '=', VNAME, '%-', VNAME},
		function(name, lh, rh)
			variables[name]=getvar(lh)-getvar(rh)
		end,
	},
	{ -- multiplication
		{VNAME, '=', VNAME, '%*', VNAME},
		function(name, lh, rh)
			variables[name]=getvar(lh)*getvar(rh)
		end,
	},
	{ -- division
		{VNAME, '=', VNAME, '/', VNAME},
		function(name, lh, rh)
			rh=getvar(rh)
			if rh==0 then
				error("Division by zero")
			end
			variables[name]=floor(getvar(lh)/rh)
		end,
	},
	{ -- modulo
		{VNAME, '=', VNAME, '%%', VNAME},
		function(name, lh, rh)
			rh=getvar(rh)
			if rh==0 then
				error("Modulo zero")
			end
			variables[name]=getvar(lh)%rh
		end
	},

	-- string operations
	{ -- concatenation
		{SNAME, '=', SNAME, '+', SNAME},
		function(name, lh, rh)
			variables[name]=getvar(lh)..getvar(rh)
		end
	},
	{ -- subchar
		{SNAME, '=', SNAME, ':', VNAME},
		function(name, str, idx)
			idx=getvar(idx)
			variables[name]=getvar(str):sub(idx, idx)
		end
	},
	{ -- substring
		{SNAME, '=', SNAME, ':', VNAME, '-', VNAME},
		function(name, str, fr, to)
			variables[name]=getvar(str):sub(getvar(fr), getvar(to))
		end
	},
	{ -- repeat
		{SNAME, '=', SNAME, '%*', VNAME},
		function(name, str, cntv)
			variables[name]=getvar(str):rep(getvar(cntv))
		end
	},

	-- conditionals
	{ -- equalty
		{VNAME, '=', VNAME, '==', VNAME},
		function(name, lh, rh)
			variables[name]=getvar(lh)==getvar(rh) and 1 or 0
		end
	},
	{ -- order
		{VNAME, '=', VNAME, '<', VNAME},
		function(name, lh, rh)
			variables[name]=getvar(lh)<getvar(rh) and 1 or 0
		end
	},
	{ -- string equalty
		{VNAME, '=', SNAME, '==', SNAME},
		function(name, lh, rh)
			variables[name]=getvar(lh)==getvar(rh) and 1 or 0
		end
	},
	{ -- string inclusion
		{VNAME, '=', SNAME, '<', SNAME},
		function(name, lh, rh)
			variables[name]=getvar(rh):find(getvar(lh), 1, true) and 1 or 0
		end
	},

	-- define color
	{ -- define color from rgb
		{NAME, '=', NUM, SEP, NUM, SEP, NUM},
		function(name, r, g, b)
			r=tonumber(r)
			g=tonumber(g)
			b=tonumber(b)
			if r<0 or r>255 then
				error("Red component is "..tostring(r)..", which is out of bounds")
			end
			if g<0 or g>255 then
				error("Green component is "..tostring(g)..", which is out of bounds")
			end
			if b<0 or b>255 then
				error("Blue component is "..tostring(b)..", which is out of bounds")
			end
			colors[name]={r, g, b}
		end
	},
	{ -- define color from rgb variables
		{NAME, '=', VNAME, OSEP, VNAME, OSEP, VNAME},
		function(name, rv, gv, bv)
			colors[name]={getvar(rv), getvar(gv), getvar(bv)}
		end
	},
	{ -- define color from gradient step
		{NAME, '=', NAME, '%%', NUM},
		function(name, grad, pct)
			colors[name]={
				calcgradient(
					tonumber(pct),
					unpack(getgradient(grad))
				)
			}
		end
	},
	{ -- define color from gradient step variable
		{NAME, '=', NAME, '%%', VNAME},
		function(name, grad, pctv)
			colors[name]={
				calcgradient(
					getvar(pctv),
					unpack(getgradient(grad))
				)
			}
		end
	},
	{ -- define color from 2d gradient xy
		{NAME, '=', NAME, '%%', NUM, '%%', NUM},
		function(name, grad2, x, y)
			colors[name]={
				calcgradient2d(
					tonumber(x),
					tonumber(y),
					unpack(getgradient2d(grad2))
				)
			}
		end
	},
	{ -- define color from 2d gradient xy variables
		{NAME, '=', NAME, '%%', VNAME, '%%', VNAME},
		function(name, grad2, xv, yv)
			colors[name]={
				calcgradient2d(
					getvar(xv),
					getvar(yv),
					unpack(getgradient2d(grad2))
				)
			}
		end
	},

	-- define gradient
	{ -- define gradient from 2 colors
		{NAME, '=', NAME, '%-', NAME},
		function(name, c1, c2)
			local r1, g1, b1=unpack(getcolor(c1))
			local r2, g2, b2=unpack(getcolor(c2))
			gradients[name]={r1, g1, b1, r2, g2, b2}
		end
	},
	{ -- define 2d gradient from 2 gradients
		{NAME, '=', NAME, '%+', NAME},
		function(name, g1, g2)
			gradients2d[name]={getgradient(g1), getgradient(g2)}
		end
	},

	-- set color
	{ -- set fg color
		{NAME},
		function(name)
			return colorize(false, unpack(getcolor(name)))
		end
	},
	{ -- set bg color
		{"b", SEP, NAME},
		function(name)
			return colorize(true, unpack(getcolor(name)))
		end
	},

	-- set gradient
	{ -- set fg gradient
		{NAME, "%%", NUM},
		function(grad, pct)
			return colorize(
				false,
				calcgradient(
					tonumber(pct),
					unpack(getgradient(grad))
				)
			)
		end
	},
	{ -- set gb gradient
		{"b", SEP, NAME, "%%", NUM},
		function(grad, pct)
			return colorize(
				true,
				calcgradient(
					tonumber(pct),
					unpack(getgradient(grad))
				)
			)
		end
	},

	-- set 2d gradient
	{ -- set fg 2d gradient
		{NAME, '%%', NUM, '%%', NUM},
		function(grad2, x, y)
			return colorize(
				false,
				calcgradient2d(
					tonumber(x),
					tonumber(y),
					unpack(getgradient2d(grad2))
				)
			)
		end
	},
	{ -- set bg 2d gradient
		{'b', SEP, NAME, '%%', NUM, '%%', NUM},
		function(grad2, x, y)
			return colorize(
				true,
				calcgradient2d(
					tonumber(x),
					tonumber(y),
					unpack(getgradient2d(grad2))
				)
			)
		end
	},

	-- display string
	{ -- directly
		{SNAME},
		function(name)
			return getvar(name)
		end
	},
	{ -- subchar
		{SNAME, ':', VNAME},
		function(str, idx)
			idx=getvar(idx)
			return getvar(str):sub(idx, idx)
		end
	},
	{ -- substring
		{SNAME, ':', VNAME, '%-', VNAME},
		function(str, fr, to)
			return getvar(str):sub(fr, to)
		end
	},

	-- marker control
	{ -- push marker
		{"!mpush"},
		function()
			return {marker='push'}
		end
	},
	{ -- pop marker
		{"!mpop"},
		function()
			return {marker='pop'}
		end
	},
	{ -- jump back to marker
		{"!mjump", OSEP, NUM, OSEP, VNAME},
		function(num, condv)
			local rel=tonumber(num)
			if getvar(condv)~=0 then
				return {marker='jump', rel=rel}
			end
		end
	},

	-- subprogram operations
	{ -- load subprogram from file
		{'!sload', SEP, NAME, SEP, FNAME},
		function(name, file)
			return {subp='load', name=name, file=file}
		end
	},
	{ -- load from string
		{'!sload', SEP, NAME, OSEP, SNAME},
		function(name, var)
			return {subp='load', name=name, var=getvar(var)}
		end
	},
	{ -- execute subprogram
		{'!srun', SEP, NAME},
		function(name)
			return {subp='run', name=name}
		end
	},
	{ -- execute subprogram conditionally
		{'!srun', SEP, NAME, OSEP, VNAME},
		function(name, condv)
			if getvar(condv)~=0 then
				return {subp='run', name=name}
			end
		end
	},
	{ -- exit from subprogram conditionally
		{'!sreturn', OSEP, VNAME},
		function(condv)
			if getvar(condv)~=0 then
				return {subp='return'}
			end
		end
	},

	-- input
	{ -- read file
		{'!read', SEP, FNAME, OSEP, SNAME},
		function(fname, str)
			variables[str]=readfile(fname)
		end
	},
	{ -- read variable file
		{'!read', OSEP, SNAME, OSEP, SNAME},
		function(fname, str)
			variables[str]=readfile(getvar(fname))
		end
	},
	{ -- read binary file
		{'!readb', SEP, FNAME, OSEP, SNAME},
		function(fname, str)
			variables[str]=readfile(fname, true)
		end
	},
	{ -- read binary variable file
		{'!readb', OSEP, SNAME, OSEP, SNAME},
		function(fname, str)
			variables[str]=readfile(getvar(fname), true)
		end
	},

	-- crash program
	{ -- without message
		{'!err'},
		function()
			error("Voluntary crash")
		end
	},
	{ -- with message
		{'!err', OSEP, SNAME},
		function(name)
			error("Crash: "..getvar(name))
		end
	},
	{ -- conditionally
		{'!err', OSEP, VNAME},
		function(cnd)
			if getvar(cnd)~=0 then
				error("Voluntary crash")
			end
		end
	},
	{ -- conditionally, with message
		{'!err', OSEP, SNAME, OSEP, VNAME},
		function(name, cnd)
			if getvar(cnd)~=0 then
				error("Crash: "..getvar(name))
			end
		end
	},

	-- control options
	{ -- add linebreak
		{"!nl"},
		function()
			return '\n'
		end
	},
	{ -- remove output
		{"!cmt"},
		function()
			return {cmt=true}
		end
	},
	{ -- output to string
		{"!wrt", OSEP, SNAME},
		function(name)
			return {wrt=name}
		end
	},
	{ -- append to string
		{"!app", OSEP, SNAME},
		function(name)
			return {app=name}
		end
	},

	-- misc
	{ -- noop
		{},
		function()
			return nil
		end
	},
	{ -- reset colors
		{"%^"},
		function()
			return string.char(27)..'[39m'..string.char(27)..'[49m'
		end
	},
	{ -- escape
		{"{"},
		function()
			return "{"
		end
	}
}

local function doline(line, subp, lineno)
	local options={}
	if #line==0 then
		return options, line
	end
	for _, filter in ipairs(stream) do
		local patt="{%s*"..table.concat(filter[1], "%s*").."%s*}"
		local fn=function(...)
			local ok, rv=pcall(filter[2], ...)
			if not ok then
				error("In subprogram "..subp..", line "..lineno..": "..rv)
			end
			local rt=type(rv)
			if rt=='nil' then
				return ''
			elseif rt=='string' then
				return rv
			elseif rt=='number' then
				return tostring(rv)
			elseif rt=='table' then
				for k, v in pairs(rv) do
					options[k]=v
				end
				return ''
			else
				error "What?"
			end
		end
		line=line:gsub(patt, fn)
	end
	return options, line
end

local subprograms={}
local function readscript(file, name)
	local lines, i={}, 1
	if file=='-' or file==nil then
		for line in io.lines() do
			lines[i], i=line, i+1
		end
	else
		for line in io.lines(file) do
			lines[i], i=line, i+1
		end
	end
	subprograms[name]=lines
end
local function loadscript(code, name)
	local lines, i={}, 1
	for line in code:gmatch "([^\n]+)" do
		lines[i], i=line, i+1
	end
	subprograms[name]=lines
end


local function doscript(name)
	local lines=subprograms[name] or error("Subprogram "..name.." not found")
	local cursor=1
	local marks={}
	while true do
		local opts, text=doline(lines[cursor], name, cursor)
		if opts.marker=='push' then
			insert(marks, cursor)
		elseif opts.marker=='pop' then
			remove(marks)
		elseif opts.marker=='jump' then
			local mark=marks[#marks-opts.rel+1]
			for i=#marks-opts.rel+1, #marks do
				marks[i]=nil
			end
			cursor=mark-1
		end
		cursor=cursor+1
		if opts.subp=='load' then
			if opts.var then
				loadscript(opts.var, opts.name)
			else
				readscript(opts.file, opts.name)
			end
		elseif opts.subp=='run' then
			doscript(opts.name)
		elseif opts.subp=='return' then
			return
		end
		if opts.app then
			local ov=variables[opts.app] or ''
			variables[opts.app]=ov..text
		elseif opts.wrt then
			variables[opts.wrt]=text
		elseif not opts.cmt then
			io.write(text)
		end
		if cursor>#lines then
			break
		end
	end
end

readscript(arg[1], 'main')
doscript('main')

