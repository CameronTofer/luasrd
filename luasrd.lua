local lpeg = require 'lpeg'
local parse = require 'moonscript.parse'
local compile = require 'moonscript.compile'


local function compile_script(moon_code)

  local tree, lua_code, msg, pos

  tree, msg = parse.string(moon_code)
  if not tree then
    return nil, msg
  end

  lua_code, msg, pos = compile.tree(tree)
  if not lua_code then
    return nil, compile.format_error(msg,pos,moon_code)
  end

  return function(name,env)
    local script = load(lua_code,name,nil,env)
    if not script then
      return nil, 'load failed'
    end
    return script
  end
end

local P, S, V, R = lpeg.P, lpeg.S, lpeg.V, lpeg.R;
local C, Cb, Cc, Cg, Cs, Cmt, Ct, Cf, Cp =
    lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cg, lpeg.Cs, lpeg.Cmt, lpeg.Ct, lpeg.Cf, lpeg.Cp;

local locale = lpeg.locale()
local Word = locale.alpha^0
local Number = locale.digit^1
local nl = P"\n"
local os = (locale.space - nl)^0
local rol = C((P(1) - P "\n" )^1) * (P "\n"^1 + -P(1));
local sm = P"---\n" ;
local nt = #(V"title" + -P(1)) ;
local Name = (locale.alpha + P "_") * (locale.alnum + P "_")^0 ;

local line = ((P(1) - P "\n" )^1) * (P "\n"^1 + -P(1));
local paragraph = line * (('\9'+P"  ") * line)^0 ;


local CapitalizedWord = (R"AZ" * (locale.alpha+"'")^1) + "without" + "1st" + (R"az"*R"az"^-3) ;
local CapitalizedTitle = CapitalizedWord * (S" /" * CapitalizedWord)^0 ;

local function kv(patt)
  return Cf(Ct("") * patt, rawset )
end

local function put(db,...)
  db = db or {}
  if select('#',...) == 2 then
    local name,content = ...
    local dest = db[name]

    if type(dest) == 'table' then
      -- unpack content into dest key
      if type(content) == 'table' then
        for k,v in pairs(content) do
          if dest[k] then
            table.insert(dest,v)
          else
            dest[k] = v
          end
        end
      else
        table.insert(dest,content)
      end

    else
      db[name] = content
    end

    return db
  end
  local path = ...
  db[path] = put(db[path],select(2,...))
  return db
end

-- path/path/key,payload => {'path','path','key','payload'}
local function putkey(db,index,key)

  local r = {}
  for _,v in pairs(key) do
    if type(v) == 'string' then
      -- convert index to path  12.13 => path, path
      local number,name = v:match('^([%d%.]+) (.+)$')
      if number then
        index[number] = name
        local path
        for h in number:gmatch('[^%.]+') do
          path = path and (path .. '.' .. h) or h
          if index[path] then
            r[#r+1] = index[path]
          end
        end
      else
        r[#r+1] = v
      end
    else
      r[#r+1] = v
    end
  end

  if #key > 1 then
    --print('\n\n')
    --p(key)
    --print('=>')
    --p(r)
    local ok, err
    ok, err = pcall(put,db,unpack(r))
    if not ok then
      print('\n\n failed to write key',err)
      p(key)
      print('=>')
      p(r)
      assert(false)
    end

    return err

  end

  return db

end

--[[

  | Header1 | Header2 | Header3 |
  | value1  | value2  | value3  |
  | value4  | value5  | value6  |

  =>

  { Header1 = {value1,value4}, Header2 = {value2,value5}, Header3 = {value3,value6}}

]]
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
    t[k] = c
  end
  return t
end

local function merge(dst,src)
  for k,v in pairs(src) do
    if dst[k] then
      table.insert(dst,v)
    else
      dst[k] = v
    end
  end
  return dst
end

local srd = P
{
  "srd",
  srd = Ct((V "section" )^0) * Cp() / function(sections,ep)

    local index = {}
    local statblocks = {}
    for _,section in ipairs(sections) do
      --print(section[1])
      statblocks = putkey(statblocks,index,section)
    end

    return statblocks,ep

  end ;


  cell = os * C((P(1) - (os * S"|\n"))^1) * os ;
  row = P"|"^-1 * Ct(V"cell" * (P"|" * V"cell")^1) * P"|"^-1 * nl^1 ;
  div = os * P"-"^1 * os ;
  rowdiv =  P"|"^-1 * (V"div" * (P"|" * V"div")^1) * P"|"^-1 * nl^1 ;
  --rows = Ct(V"row"^1) ;

  rows = Ct(V"row" * V"rowdiv"^-1 * V"row"^1) / columns ;


  content = rol - V"title" ;


  -- anything until code, table, or new section
  description = C( (P(1) - (nl^1 * (sm + V"title" + V"row")))^1  ) * nl^0 ;

  -- a list of name: desc\n
  properties = kv(V"property"^1) ;

  property =

    Cg(( C(CapitalizedTitle) * ":" * os * C(P"(" * Name * (os * "," * os * Name)^0 * os * ")" * os * (P"->" + P"=>") * paragraph) ) / function(name,source)
      local f = compile_script(source)
      if f then
        return name,f(name,_G)
      end
      return name,source
    end) +

    -- name: value
    Cg(C(CapitalizedTitle) * ": " * rol) ;


  --
  script = sm * V"description" * sm^-1 * nl^0 / function(source)
    local script,err = compile_script(source)
    if not script then
      print(err)
    end
    return script
  end ;

  title = C(Number * ("." * Number)^0 * " " * Word * ((Number + S"/,:'- ") * Word)^0) * nl^1 ;

  name = C(Word * (" " * Word)^0) ;


  --
  --  sections
  --
  section =


  -- list of names
  Ct(V"title" * Ct((C(CapitalizedTitle) * nl)^1) * nt) +


  -- Generic
  (V"title" * Ct((V"properties" + V"rows" + V"script" + V"content")^0) * nt / function(name,contents)

    local content = {}
    for _,v in pairs(contents) do

      if type(v) == 'function' then
        content = v(name,_G)()(content)
      else
        if type(v) == 'table' then
          merge(content,v)
        else
          table.insert(content,v)
        end
      end

    end

    return {name,content}

  end) ;
}

return function(source)

  local r,ep = lpeg.match(srd,source)

  if ep <= #source then
    local ok = source:sub(1,ep)
    local lineNumber = select(2,ok:gsub('\n','\n')) + 1
    local column = #ok:gsub('.*\n','') - 1
    return nil, 'script:'..lineNumber..':'..column..': syntax error\n"'..source:sub(ep) ..'"'
  end

  return r

end

