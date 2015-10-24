# End Of File
# 
# Files should end with an empty line. This prevents the diff from showing the
# last line of code when additional code is appended to the file. It's also nice
# for text editors that are smart enough to copy the line feed when an entire
# line is copied.


# Indentation
# 
# Lines should be indented with 2 spaces. This is a Ruby convention.
def my_method
  @items.each do |item|
    do_something_with item
    do_something_else
  end
end


# Leading Spaces
# 
# Leading spaces between lines _should_ be used. Some text editors return the
# cursor back to the beginning of the line when an empty line is encountered,
# which makes it cumbersome to navigate a file.
def my_method
··array = [1, 2, 3]
··
··array.each do |i|
····number = an_equation i 
····
····do_something_with number
··end
end


# Trailing Commas
# 
# Use trailing commas at the end of multi-line lists. This prevents the diff
# from showing lines that weren't actually changed if a contributor needs to
# add to the list.
data = [
  "foo",
  "bar",
  "baz",
]

data = {
  foo: 1,
  bar: 2,
  baz: 3,
}


# Parenthesis
# 
# Prefer omitting parenthesis unless they are needed to clarify the code for the
# compiler or another programmer. When using parenthesis, prefer them on the
# inner-most items of an expression first.
def my_method x, y
  File.exists? File.expand_path("../lib", __FILE__)
end

# Parenthesis may also be needed when parameters are used with a `{}` block.
let(:foo) { "bar" }


# Hash Rocket
# 
# Prefer the colon syntax over the hash rocket `=>`. This takes up less space,
# requires fewer characters, and more closely relates the value to the key.
data = {foo: 1, bar: 2, baz: 3}


# Keyword Args
# 
# Prefer `**kwargs` over `opts = {}` when targeting Ruby >= 2.0.
def my_method **kwargs
  var_1 = kwargs.fetch :var_1
end

def my_method var_1: 123
  do_something_with var_1
end


# Blocks: `do` vs `{}`
# 
# Prefer `{}` for block chaining. Prefer `do` for multi-line blocks that don't
# chain. If you have to chain multi-line blocks, prefer `{}` but use your best
# judgement.
list
  .map { |i| i + 1 }
  .reduce { |acc, i| acc + i }

list
  .map { |i|
    i = 10 unless i
    secret_formula i
  }
  .reduce { |acc, i|
    data = i > 50 ? formula_1(i) : formula_2(i)
    acc + data
  }

XML::Doc.new.tap do |doc|
  XML::Element.new("Data").tap do |data_element|
    doc << data_element
    
    XML::Element.new("Result").tap do |result|
      data_element << result
      
      result.text = "4"
    end
  end
end


# Ternary
# 
# Prefer the ternary operator `?` for conditional assignment that can fit on a
# single line. Do not use it to replace conditional logic.
x = data > 50 ? formula_1(data) : formula_2(data)

# Don't do this!
threat_level > 50 ? fire_missiles : remain_calm


# `and`, `or` vs `&&`, `||`
# 
# *NOTE* I'm still up in the air about this. Here's my opinion so far:
# Prefer `or` in conditional logic. Prefer `||` for assignment (due to behavior).
if foo or bar
  perform_task
end

x = foo || bar


# Whitespace
# 
# The use of whitespace should be used reasonably, but not excessively. The code
# should flow smoothly and be easy to read. As in graphic design, the use of
# whitespace should be used as a tool to move the viewer's eye through the
# document and accentuate areas of importance.
#
# Whitespace should be used:
#   * After a comma
#   * After a colon `:`, like when defining a hash
#   * Between operators, like `+` or `=>`
#   * Between the braces `{}` of a block
#   * To separate logical groups of code or ideas

# Spaces after commas.
# Note that spaces are not necessary between `[]`. This is because the brackets
# are enclosing related items, so the close proximity of the brackets to the 
# data better conveys the concept of a group.
data = ["foo", "bar", "baz"]

# Spaces after colons.
# Note that spaces are not necessary between `{}`. This is because the braces
# are enclosing related items, so the close proximity of the braces to the 
# data better conveys the concept of a group.
data = {foo: 1, bar: 2, baz: 3}

def my_method data: 25
  # ...
end

# Spaces between `{}` of a block.
# Whitespace helps to separate the block parameters from the statement, making
# the code easier to read and separating unrelated elements. If the block
# doesn't contain parameters, include the spaces between `{}` for consistency.
data.map { |item| item + 1 }

let(:foo) { "bar" }

# Spaces between operators.
x = data > 10 ? data + 5 : data * 2

# Whitespace separating logical groups: Assignment, calculation, return value.
def my_method data
  x = data || 25
  
  computed_data =
    @list
      .map { |i| secret_formula i } # Spaces between `{}` of a block.
      .reduce { |acc, i| acc + i }
  
  computed_data + x
end 

# This is a gray area where use of a separating line is up to the discretion of
# the author. A two-line map statement like this is so simple that adding a
# separating line probably doesn't increase the clarity of the code.
list.map do |i|
  i = 10 unless i
  secret_formula i
end

# If the two statements are more complex, then a separating line might increase
# clarity and readability.
list.map do |i|
  x = i > 50 ? formula_1(i) : formula_2(i)
  
  secret_formula x
end
