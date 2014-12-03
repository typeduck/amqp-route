###############################################################################
# Publisher Generation using templates
###############################################################################

_ = require("lodash")

module.exports = class Publisher
  # Constructs our publisher
  constructor: (@conn, @template, opts, done) ->
    @exOptions = _.merge(@template.exchangeOpts, opts)
    if ex = findExchange(@conn, @template.exchange, @exOptions)
      @exchange = ex
      done(null, @)
    else
      ex = @conn.exchange @template.exchange, _.clone(@exOptions), (exc) =>
        @exchange = exc
        done(null, @)
      saveExchange(@conn, ex, @exOptions)
  # Publishes a message using Template
  publish: (sources, data, opts, done) ->
    if typeof opts is "function"
      done = opts
      opts = {}

    rk = @template.fill.apply(@template, sources)
    options = _.merge(@template.pubOpts, opts)
    if not @exOptions.confirm
      @exchange.publish(rk, data, options)
      process.nextTick () -> done?()
    else
      @exchange.publish rk, data, options, (isErr) ->
        if isErr
          done?(new Error("Failed to publish to #{rk}"))
        else
          done?()

# Cache of Exchanges that can be reused
exchanges = {}

findExchange = (conn, name, opts) ->
  uniq = "#{conn.options.url}::#{name}"
  others = (exchanges[uniq] ?= [])
  found = false
  for c in others
    if _.isEqual(c.options, opts)
      return c.exchange
  return null

saveExchange = (conn, ex, opts) ->
  uniq = "#{conn.options.url}::#{ex.name}"
  (exchanges[uniq] ?= []).push({
    exchange: ex
    options: opts
  })
