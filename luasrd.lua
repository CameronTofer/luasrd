local parse = require 'moonscript.parse'
local compile = require 'moonscript.compile'
local re = require 're'

local env

local srd = re.compile([[

  all <- {| block* |} -> group {}

  block <- ({: {:index: index:} " " {title} %nl+
            {| ((&(=index "." index) block) / rows  / method / prop / parse / &!index (&.)->'' line)* |} -> group
            :})

  index <- %d+("."%d+)*
  title <- %a+ (os [%d%a]+)*
  line <- {[^%nl]*} %nl+

  prop <- {captitle} ":" os line
  captitle <- capword (os capword)*
  capword <- [A-Z]%a+ / %d%a%a / %a%a

  rows <- {| row rowdiv? row+ |} -> columns
  rowdiv <- ((os [|-])+ %nl)
  row <- {| "|"? cell ("|" cell)+ "|"? |} (%nl+ / !.)
  cell <- os {cnts (os cnts)*} os
  cnts <- [^|%s]+

  method <- {captitle} ":" {os ('(' [^')']* ')')? os ('->'/'=>') rol ('  ' rol)*} -> code

  parse <- (&.)->'-parse' sm (( &!(index/sm) rol)*) -> code sm?
  sm <- '---' %nl+

  rol <- [^%nl]* %nl+

  os <- " "*

]],{
  group=function(all)
    local r = {}
    for i=1,#all,2 do
      local k = all[i]
      local v = all[i+1]

      if k == '-parse' then
        r = v(k)(r)
      elseif type(v) == 'function' then
        r[k] = v(k)
      elseif k == '' then
        table.insert(r,v)
      else
        r[k] = v
      end
    end
    return r
  end,
  columns = function( rows )
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
  end,
  code = function(code)
    local tree, lua_code, msg, pos

    tree, msg = parse.string(code)
    if not tree then
      return nil, msg
    end

    lua_code, msg, pos = compile.tree(tree)
    if not lua_code then
      return nil, compile.format_error(msg,pos,code)
    end

    return function(name)
      return load(lua_code,name,nil,env)()
    end

  end,
  rawset=rawset,
})


return function(source)

  env = {}

  local db,ep = srd:match(source)

  if ep <= #source then
    local ok = source:sub(1,ep)
    local lineNumber = select(2,ok:gsub('\n','\n')) + 1
    local column = #ok:gsub('.*\n','') - 1
    return nil, nil, 'script:'..lineNumber..':'..column..': syntax error\n"'..source:sub(ep) ..'"'
  end

  return db,env

end

