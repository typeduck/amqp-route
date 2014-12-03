###############################################################################
# AMQP Data Routing Helpers
###############################################################################

Template = require("./Template")
exports.template = (s) -> new Template(s)

Publisher = require("./Publisher")
exports.publisher = (conn, s, opts, done) ->
  if typeof s is "string" then s = new Template(s)
  if typeof opts is "function"
    done = opts
    opts = {}
  new Publisher(conn, s, opts, done)
