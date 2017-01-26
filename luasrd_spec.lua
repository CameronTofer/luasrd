local describe = describe
local it = it

local srd = require 'luasrd'
local serpent = require 'serpent'

local function dump(var)
  return serpent.block(var,{nocode = true,comment=false})
end


describe("an srd", function()

  --
  it("can be empty",function()
    local db, err = srd('')
    assert.is_not_nil(db)
    assert.is_nil(err)
    assert.are.equal(0, #db)
  end)

  --
  it("must have sections", function()
    local db, err = srd('hello')
    assert.is_nil(db)
    assert.is_not_nil(err)
  end)

  --
  it("has sections to organize content", function()

    local db, err = srd(
[[
1.1 Content
Hello World.
]])

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

    local db, err = srd([[
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

    local db, err = srd([[
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

    local db, err = srd([[
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

    local db, err = srd([[
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

    local db,err = srd[[
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

    local db, err = srd[[
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

    local db, err = srd[[
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


  end)


  it("can have sections within sections", function()

    local db, err = srd[[
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

end)
