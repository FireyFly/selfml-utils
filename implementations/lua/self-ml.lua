----------------------------
-- self-ml parsing module --
----------------------------

---- Helper functions -----------------------------------------------
-- checks if the given character is a whitespace character
local function is_whitespace(chr)
  return string.match(chr, "^%s$")
end

-- checks if the given string+position is valid in a bareword
local function is_bareword_idx(str, idx)
  -- for now, we allow []` inside a bareword; this could have its uses, and
  -- the readme isn't entirely clear on how they should be treated.
  local chr = str:sub(idx, idx)

  return chr ~= "#" and chr ~= "(" and chr ~= ")"
     and not is_whitespace(chr)
     and str:sub(idx, idx+1) ~= "{#"
end


---- Sub-parsing functions ------------------------------------------
local function parse_line_comment(str, idx)
  while str:sub(idx, idx) ~= "\n" and idx <= #str do
    idx = idx + 1
  end

  return idx
end

local function parse_block_comment(str, idx)
  local count = 1
  idx = idx + 2

  while idx <= #str do
    local chr = str:sub(idx, idx)

    if chr == "#" then
      local prevChr = str:sub(idx-1, idx-1)
      local nextChr = str:sub(idx+1, idx+1)

      if prevChr     == "{" then count = count + 1
      elseif nextChr == "}" then count = count - 1
      end
    end

    idx = idx + 1

    -- break after increment so that we'll catch the last } in '#}' as well
    if count == 0 then break end
  end

  return idx
end

local function parse_bracketed_string(str, idx)
  local first, last = str:find("%b[]", idx)
  local word = str:sub(first + 1, last - 1)

  return last, word
end

local function parse_quoted_string(str, idx)
  local first = idx + 1

  while idx <= #str do
    idx = idx + 1

    local chr     = str:sub(idx, idx)
    local nextChr = str:sub(idx+1, idx+1)

    if chr == "`" then
      -- skip double backticks, break on single backtick
      if nextChr == "`" then idx = idx + 1
      else                   break
      end
    end
  end

  local word = str:sub(first, idx - 1):gsub("``", "`")

  return idx, word
end

local function parse_whitespace(str, idx)
  while is_whitespace(str:sub(idx, idx)) do
    idx = idx + 1
  end

  return idx - 1
end

local function parse_bareword(str, idx)
  local first = idx

  while is_bareword_idx(str, idx) do
    idx = idx + 1
  end

  local word = str:sub(first, idx-1)

  return idx - 1, word
end


---- Main parsing function ------------------------------------------
-- parses string into s-expr structure (nested lists)
local function parse(str)
  local idx = 1   -- curr pos in string

  local curr = {}        -- curr node to append to
  local leftParens = {}  -- stack of nodes used for handling parens

  -- the main parse loop.  For each iteration, we figure out what to parse,
  -- and then use an inner loop to actually parse that token.  That is,
  -- each iteration of this main loop handles exactly one token.
  --   Parens are special-cased.
  while idx <= #str do
    local chr = str:sub(idx, idx)

    -- opening paren: step inside paren group
    if chr == "(" then
      table.insert(leftParens, curr)

      -- create a new node and make it curr
      local newNode = {}
      table.insert(curr, newNode)
      curr = newNode

    -- closing paren: step out of paren group
    elseif chr == ")" then
      assert(#leftParens > 0, "right paren with no matching left paren")
      curr = table.remove(leftParens)

    else
      local fun, word

      -- find out what to parse this token as
      if     chr == "#"                  then fun = parse_line_comment
      elseif str:sub(idx, idx+1) == "{#" then fun = parse_block_comment
      elseif is_whitespace(chr)          then fun = parse_whitespace
      elseif chr == "["                  then fun = parse_bracketed_string
      elseif chr == "`"                  then fun = parse_quoted_string
      else                                    fun = parse_bareword
      end

      -- do the parsing, then add token if token was produced
      idx, word = fun(str, idx)
      if word then table.insert(curr, word) end
    end

    idx = idx + 1
  end

  assert(#leftParens == 0, "unterminated left paren")

  return curr
end


---- Prettyprinter helpers ------------------------------------------
-- checks whether the given node forms the root of a star graph
-- (that is, whether all its children are leaf nodes).
local function is_star_subtree(node)
  -- a star subtree has to have a table as the root node
  if type(node) ~= 'table' then return false end

  for i,v in ipairs(node) do
    -- the table cannot contain further internal nodes
    if type(v) == 'table' then return false end
  end

  return true
end

-- maps the given function over the given list
local function map(arr, fn)
  local res = {}

  for i,v in ipairs(arr) do
    res[i] = fn(arr[i], i, arr)
  end

  return res
end

-- limits a function to a given amount of arguments
function limit(fn, maxcount)
  return function(...)
    for i=maxcount+1, #arg do
      arg[i] = nil
    end

    return fn(unpack(arg))
  end
end


---- Prettyprinting function ----------------------------------------
-- prettyprints s-expr structure (nested lists)
-- TODO: Improve.  Currently rather horrible
local function prettyprint(node, indent)
  indent = indent or ""

  -- start by checking simple cases
  if type(node) == 'string' then
    -- strings -- either bare words or containing whitespace
    if node:match("%s")     or
       node:match("[%[%]]") or #node == 0 then
      return indent .. "`" .. node:gsub("`", "``") .. "`"
    else
      return indent .. node
    end

  elseif #node == 0 then
    -- empty list - not supported by self-ml, but we allow the prettyprinter to
    -- prettify it for good measure.
    return indent .. "()"

  elseif is_star_subtree(node) then
    -- since the node has no subtrees, we print it all in one line
    local mapped = map(node, limit(prettyprint, 1))
    return indent .. "(" .. table.concat(mapped, " ") .. ")"
  end

  -- handle the general case (non-empty list)
  local res = indent .. "(" .. prettyprint(node[1])

  for i=2, #node do
    res = res .. "\n" .. prettyprint(node[i], indent .. "  ")
  end

  res = res .. ")"
  return res
end


---- Exposed stuff --------------------------------------------------
return { parse       = parse
       , prettyprint = prettyprint
       , parseFile   = function(file)
                         if type(file) == 'string' then
                           file = assert(io.open(file, "r"))
                         end

                         return parse(file:read("*a"))
                       end
       }
