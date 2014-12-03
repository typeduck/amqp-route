###############################################################################
# AMQP Data Routing Helpers
###############################################################################

exports.template = (s) -> new Template(s)

###############################################################################
# Exchange and Routing Key Template
###############################################################################
rxTemplate = /// ^
  (?:  # Exchange + Options
    ([^\/?]+)         # Exchange: no slash or question mark
    (?:\?([a-z-]*))?  # Options are... optional
  \/)? # End optional Exchange + Options capture
  (?:  # Routing Key + Options
    ([^?]+)           # Routing Key template: no question marks
    (?:\?([a-z-]*))?  # Options are... optional
  )    # End Routing Key Template + Options capture
///

exports.Template = class Template
  constructor: (tpl) ->
    if not (m = rxTemplate.exec(tpl))
      throw new Error("Bad Template Syntax '#{tpl}'")
    @exchange = m[1] || ""
    @exchangeOpts = setExchangeOptions(m[2])
    @template = m[3]
    @pubOpts = setPublishOptions(m[4])
  # Fills in the template using the list of sources provided
  fill: (sources...) ->
    filled = @template.replace /\{([^}]+)\}/g, (match, k) ->
      return obj[k] for obj in sources when obj?[k]?
      return ""
    filled.replace(/\.{2,}/g, ".").replace(/^\.|\.$/g, "")

# Exchange Options
rxExchangeOpt = /(-)?([adcnp])/g
exchangeMap =
  a: "autoDelete"
  d: "durable"
  c: "confirm"
  n: "noDeclare"
  p: "passive"
setExchangeOptions = (s) ->
  return {} if not s
  opts = {}
  while (m = rxExchangeOpt.exec(s))
    opts[exchangeMap[m[2]]] = ! m[1]
  return opts

# Publishing Options
rxPubOpt = /(-)?([mip])/g
pubMap =
  m: "mandatory"
  i: "immediate"
setPublishOptions = (s) ->
  return {} if not s
  opts = {}
  while (m = rxPubOpt.exec(s))
    if m[2] is "p"
      opts.deliveryMode = if m[1] then 1 else 2
    else
      opts[pubMap[m[2]]] = ! m[1]
  return opts
