local describe = describe
local it = it

--local srd = require './luasrd'
local srd = loadfile('luasrd.lua')()
local serpent = require 'serpent'

local function dump(var)
  return serpent.block(var,{nocode = true,comment=false})
end


describe("an srd", function()

  --
  it("can be empty",function()
    local db, env, err = srd('')
    assert.is_not_nil(db)
    assert.is_not_nil(env)
    assert.is_nil(err)
    assert.are.equal(0, #db)
  end)

  --
  it("must have sections", function()
    local db, env, err = srd('hello')
    assert.is_nil(db)
    assert.is_nil(env)
    assert.is_not_nil(err)
  end)

  it("can have empty lines before sections", function()
    local db, env, err = srd('\n\n1.1 Hello\n')
    assert.is_nil(err)
    assert.is_not_nil(db)
    assert.is_not_nil(env)
  end)

  it("doesn't have to have a new line at the end", function()
    local db, env, err = srd('1.1 Hello')
    assert.is_nil(err)
    assert.is_not_nil(db)
    assert.is_not_nil(env)
  end)

  --
  it("has sections to organize content", function()

    local db, env, err = srd(
[[
1.1 Content
Hello World.
]])

    assert.is_not_nil(env)
    assert.is_nil(err)
    assert.are.equal(
[[
{
  Content = {
    "Hello World."
  }
}]],dump(db))

  end)


  --
  it("can have sections that have sections", function()

    local db = srd([[
1 Content
1.1 Text
Hello World.
Goodbye.
]])

    assert.are.equal([[
{
  Content = {
    Text = {
      "Hello World.",
      "Goodbye."
    }
  }
}]],dump(db))

  end)


  --
  it("can have sections with tables", function()

    local db = srd([[
1 Content
1.1 Data
Number|Description
2|Two
3|Three
11|Eleven
]])

    assert.are.equal([[
{
  Content = {
    Data = {
      Description = {
        "Two",
        "Three",
        "Eleven"
      },
      Number = {
        2,
        3,
        11
      }
    }
  }
}]],dump(db))

    end)


  it("can have tables with dividers", function()

    local db = srd([[
1 Content
1.1 Data

| Number | Description |
| ------ | ----------- |
| 2      | Two         |
| 3      | Three       |

]])

    assert.are.equal([[
{
  Content = {
    Data = {
      Description = {
        "Two",
        "Three"
      },
      Number = {
        2,
        3
      }
    }
  }
}]],dump(db))

  end)


  it("can have tables with dividers", function()

    local db = srd([[
1 Content
1.1 Data

| Number | Description |
| ------ | ----------- |
| 2      | Two         |
| 3      | Three       |

]])

    assert.are.equal([[
{
  Content = {
    Data = {
      Description = {
        "Two",
        "Three"
      },
      Number = {
        2,
        3
      }
    }
  }
}]],dump(db))

  end)



  it("can have multiple tables per section", function()

    local db = srd[[
1.1 Sample Data
| Index | Name |
| 1     | poo  |
| 2     | fart |
This is text
| Power | Source |
| 10    | Farts  |
| 12    | Snot   |
]]

    assert.are.equal([[
{
  ["Sample Data"] = {
    "This is text",
    Index = {
      1,
      2
    },
    Name = {
      "poo",
      "fart"
    },
    Power = {
      10,
      12
    },
    Source = {
      "Farts",
      "Snot"
    }
  }
}]],dump(db))

  end)


  it("can have script to modify contents of a section", function()

    local db = srd[[
1.1 Very Interesting Things
Some text
| Name | Value |
| poo  | 1     |
| fart | 2     |
---
(c) ->
  c.Method = (i,v) -> c.Value[i] + v
  c
]]

  assert.are.equal([=[
{
  ["Very Interesting Things"] = {
    "Some text",
    Method = function() --[[..skipped..]] end,
    Name = {
      "poo",
      "fart"
    },
    Value = {
      1,
      2
    }
  }
}]=],dump(db))


  end)



  it("can include functions as content", function()

    local db = srd[[
1.1 Man
Name: Bob Wilson
Height: Tall
Sum: (a,b) -> a+b
]]

    assert.are.equal([=[
{
  Man = {
    Height = "Tall",
    Name = "Bob Wilson",
    Sum = function() --[[..skipped..]] end
  }
}]=],dump(db))


    assert.are.equal( 33, db.Man.Sum(11,22))

  end)


  it("can have sections within sections", function()

    local db = srd[[
1 Parent
Name: Fiz
1.1 Child
Name: Sam
1.1.1 Grandchild 1
Name: Bob
1.1.2 Grandchild 2
Name: Sally
1.2 Another child
Name: Roger
]]

  assert.are.equal([=[
{
  Parent = {
    ["Another child"] = {
      Name = "Roger"
    },
    Child = {
      ["Grandchild 1"] = {
        Name = "Bob"
      },
      ["Grandchild 2"] = {
        Name = "Sally"
      },
      Name = "Sam"
    },
    Name = "Fiz"
  }
}]=],dump(db))


  end)


  it("can have sections with code that parse", function()

    local db = srd[[
1 Heading
1.1 Data
This is one line
This is two line
---
(content) ->
  'We have ' .. #content .. ' lines.'
]]

    assert.are.equal( 'We have 2 lines.', db.Heading.Data )

  end)

  it("has functions that share an environment.", function()

    local db, env = srd[[
1 Test
DoIt: -> X + 3
]]

    env.X = 4
    assert.are.equal( 7, db.Test.DoIt() )
    env.X = 1
    assert.are.equal( 4, db.Test.DoIt() )

  end)

  it("has functions which can be multiple lines", function()

    local db = srd[[
1 Test
myfunc: (x) ->
  1 + (3 * x)
]]

    assert.are.equal( 10, db.Test.myfunc(3) )

  end)

end)
