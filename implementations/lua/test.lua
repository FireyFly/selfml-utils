local self_ml = require 'self-ml'

local tree = self_ml.parseFile("test.selfml")

print("--- Done!")
for _,node in ipairs(tree) do
  print(self_ml.prettyprint(node))
end
