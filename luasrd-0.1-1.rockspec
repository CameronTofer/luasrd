package = "luasrd"
version = "0.1-1"
source = {
   url = "git://github.com/CameronTofer/luasrd",
   tag = "v0.1",
}
description = {
   summary = "A tool for converting srd documents to lua tables.",
   detailed = [[
      This is a tool that can parse documents that
      contain text, tables and code into lua tables
      that can be used from lua code.
   ]],
   homepage = "https://github.com/CameronTofer/luasrd",
   license = "MIT/X11"
}
dependencies = {
   "lua >= 5.1, < 5.4",
   "lpeg >= 1.0.1",
   "moonscript >= 0.5.0",
}
build = {
  type = "builtin",
  modules =
  {
    luasrd = "luasrd.lua",
  }
}