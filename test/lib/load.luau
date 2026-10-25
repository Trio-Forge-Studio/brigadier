local B = require("./package")
-- `then` is a Luau keyword, so the specs call ArgumentBuilder.then `with`.
B.ArgumentBuilder.with = B.ArgumentBuilder["then"]

return B
