local to_lua = require 'moonscript.base'.to_lua
local re = require 're'
local serpent = require 'serpent'

local function dump(v)
  return serpent.block(v,{nocode = true,comment=false})
end
local function p(var)
  print(dump(var))
end

return function(source,sourcename,extensions,...)

  local env = {}
  local inf = {debug = {}, index={}, sources={}}
  local firstLineNumber = 0

  if sourcename == nil then
    sourcename = debug.getinfo(2,'S').short_src
    firstLineNumber = debug.getinfo(2,'l').currentline
  end

  local function pos2line(text,pos)
    local l = text:sub(1,pos)
    local lineNumber = select(2,l:gsub('\n','\n')) + 1
    local column = #l:gsub('.*\n','') - 1
    return lineNumber,column
  end

  -- converts an array of key/values into a list
  local function group(all)
    local r = {}
    for i=1,#all,2 do
      local k = all[i]
      local v = all[i+1]
      if k == '-parse' then
        assert(v)
        r = v(k)(r)
        k = nil
      elseif type(v) == 'function' then
        v = v(k)
      elseif k == '' then
        k = #r+1
      end

      if k then
        r[k] = v

        -- keep track of the names of things
        if type(v) == 'table' and type(k) == 'string' then
          inf.index[v] = k
        end
      end

    end
    return r
  end

  -- converts array of rows into a list of columns
  local function columns( rows )
    local t = {}
    for x,k in pairs(rows[1]) do
      local c = {}
      k = tonumber(k) or k
      for y=2,#rows do
        local vv = rows[y][x]
        if vv and vv ~= '' then
          local n = vv:gsub(',','')
          table.insert(c,tonumber(n) or vv)
        end
      end
      table.insert(t,k)
      table.insert(t,c)
    end
    return unpack(t)
  end


  -- compile moon script
  local function code(pos,moonscript)

    local luascript, info = to_lua( moonscript )

    pos = pos2line(source,pos)

    if not luascript then
      local lineNumber = firstLineNumber + pos
      error(sourcename..':'..lineNumber..': '..info,0)
    end


    info[1] = pos
    for k,v in pairs(info) do
      info[k] = pos + pos2line(moonscript,v) - 1
    end

    return function(name)
      if name ~= '-parse' then
        name = name .. ':' .. pos
        inf.debug[name] = info
        inf.sources[name] = luascript
      end
      return load(luascript,name,nil,env)()
    end

  end

  local srd = re.compile([[

    all <- %nl* {| block* |} -> group {}

    block <- ({: {:index: index:} " " {title} %nl*
              {| ((&(=index "." index) block) / rows  / %extensions / method / prop / parse / &!heading (&.)->'' line)* |} -> group
              :})

    heading <- index " " title
    index <- %d+("."%d+)*
    title <- [%d%a]+ (os [%d%a]+)*
    line <- {[^%nl]+} (%nl+ / !.)

    prop <- {captitle} ":" os line
    captitle <- capword (os capword)*
    capword <- [A-Z]%a+ / %d%a%a / %a%a%a

    rows <- {| row rowdiv? row+ |} -> columns
    rowdiv <- ((os [|-])+ %nl)
    row <- {| "|"? cell ("|" cell)+ "|"? |} (%nl+ / !.)
    cell <- os {cnts (os cnts)*} os
    cnts <- [^|%s]+

    method <- {captitle} ":" ({} {os ('(' [^')']* ')')? os ('->'/'=>') rol ((%s+) rol)*}) -> code

    parse <- (&.)->'-parse' sm ({} {( &!(heading/sm) rol)*}) -> code sm?
    sm <- '---' %nl+

    rol <- [^%nl]* %nl+

    os <- " "*

  ]],{
    group=group, columns=columns, code=code, extensions=re.compile(extensions or [['&.']],...)
  })
  local db,ep
  local ok,err = pcall( function()
    db,ep = srd:match(source)

    if ep <= #source then
      local ok = source:sub(1,ep)
      local lineNumber = select(2,ok:gsub('\n','\n')) + 1
      local column = #ok:gsub('.*\n','') - 1
      error('script:'..lineNumber..':'..column..': syntax error\n"'..source:sub(ep) ..'"')
    end
  end)

  if not ok then
    return nil,nil,err
  end

  if inf then
    db = setmetatable(db,{__index =
    {
      __inf = inf,
      __scope = function(msg,sourcefile)
        return msg:gsub('%[string "([%d%a%.]+:%d+)"%]:(%d+)',function(n,o)
          local line = inf.debug[n][tonumber(o)]
          return sourcefile..':'..(line or '0')
        end)
      end,
      __nameof = function(thing)
        return inf.index[thing]
      end,

      trace = function()

        -- split sources into lines
        inf.trace = {}
        inf.stack = {}
        for k,v in pairs(inf.sources) do
          local r = {}
          for line in v:gmatch('([^\n]*)\n') do
            r[#r+1] = {line=line,locals={}}
          end
          inf.trace[k]=r
        end

      end,

      render = function()

        for name,src in pairs(inf.trace) do

          io.write('-- ',name,'\n')

          for _,line in pairs(src) do

            local source = line.line
            local printed = false
            for k,v in pairs(line.locals) do
              io.write(string.format('%s  -- %s = %s\n',source,k,table.concat(v,' | ')))
              source = ''
              printed = true
            end

            if not printed then
              if line.temp then
                io.write(string.format('%s  -- %s\n',source,line.temp))
              else
                io.write(source,'\n')
              end
            end


          end

          io.write('\n')

        end

      end,

      hook = function(ht)

        local function getlocals()
          local r = {}
          local t = {}
          for i=1,100 do
            local k,v = debug.getlocal(3,i)
            if not k then break end
            if k == '(*temporary)' then
              if type(v) == 'number' and v == math.floor(v) then
                table.insert(t,v)
              end
            else
              r[k] = v
            end
          end
          return r,t
        end

        -- see if we're in source
        local di = debug.getinfo(2)
        local trace = inf.trace[di.source]
        if not trace then
          return
        end

        -- find the level of the call stack
        local levels = 3
        while debug.getinfo(levels, "") do
          levels = levels + 1
        end

        if ht == 'call' then
          inf.stack[levels] = { locals = {}, ls = di.currentline }
        else

          local cs = inf.stack[levels]
          if not cs then
            return
          end
          local line = trace[cs.ls]
          if not line then
            return
          end

          local locals,temp = getlocals()

          for k,v in pairs(locals) do
            if v ~= cs.locals[k] then
              line.locals[k] = line.locals[k] or {}
              table.insert(line.locals[k], tostring(v) or v)
            end
          end
          line.temp = temp[1]

          cs.locals = locals
          cs.ls = di.currentline

        end


      end,
    }})
  end

  return db,env

end

