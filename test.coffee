###############################################################################
# AMQP Data Routing Testing
###############################################################################

require("should")
routes = require("./index")

describe "amqp-route.template", () ->
  
  it "should compile a route template", () ->
    r1 = "My-Exchange/literal.{k1}.{k2}.{none}.{k3}"
    sample = routes.template(r1)
    sample.exchange.should.equal("My-Exchange")
    sample.template.should.equal("literal.{k1}.{k2}.{none}.{k3}")
    rk = sample.fill({k1: "foo", k2: "bar"}, {k2: "baz", k3: "crud"})
    rk.should.equal("literal.foo.bar.crud")

  it "should not *require* an Exchange", () ->
    r1 = "literal.{k1}.{k2}.{none}.{k3}"
    sample = routes.template(r1)
    sample.exchange.should.equal("")
    sample.exchangeOpts.should.eql({})
    sample.template.should.equal("literal.{k1}.{k2}.{none}.{k3}")
    sample.pubOpts.should.eql({})
    rk = sample.fill({k1: "foo", k2: "bar"}, {k2: "baz", k3: "crud"})
    rk.should.equal("literal.foo.bar.crud")

  it "should compile an exchange with options", () ->
    r1 = "My-Exchange?-adc/routing.key"
    sample = routes.template(r1)
    sample.exchange.should.equal("My-Exchange")
    sample.exchangeOpts.should.eql({
      autoDelete: false
      durable: true
      confirm: true
    })

  it "should compile an exchange AND template with options", () ->
    r1 = "My-Exchange?-adc-n-p/routing.{k1}.{k2}?mip"
    sample = routes.template(r1)
    sample.exchangeOpts.should.eql({
      autoDelete: false
      noDeclare: false
      passive: false
      durable: true
      confirm: true
    })
    sample.template.should.equal("routing.{k1}.{k2}")
    sample.pubOpts.should.eql({
      mandatory: true
      immediate: true
      deliveryMode: 2
    })
    filled = sample.fill({k1: "here", k2: null})
    filled.should.equal("routing.here")

  it "should compile Routing Key with options, no Exchange", () ->
    r1 = "routing.{k1}.{k2}?mip"
    sample = routes.template(r1)
    sample.exchange.should.equal("")
    sample.template.should.equal("routing.{k1}.{k2}")
    sample.pubOpts.should.eql({
      mandatory: true
      immediate: true
      deliveryMode: 2
    })

###############################################################################
# Tests that we can get a Publisher
###############################################################################
describe "amqp-route.publisher", () ->
  amqp = require("amqp")
  async = require("async")
  auto = null
  messages = []
  pushMessage = (msg, headers, info, m) ->
    messages.push {body: msg, headers: headers, info: info, ack: m}

  before (done) ->
    if not process.env.AMQPCONN
      return done(new Error("process.env.AMQPCONN must be set (AMQP URL)"))
    async.auto {
      conn: (next) ->
        opts = {url: process.env.AMQPCONN}
        conn = amqp.createConnection(opts, {reconnect: false})
        conn.on "error", (e) -> console.error(e)
        conn.on "ready", () -> next(null, conn)
      exchange: ["conn", (next, auto) ->
        auto.conn.exchange "My-Exchange", {}, (ex) -> next(null, ex)
      ]
      queue: ["conn", (next, auto) ->
        auto.conn.queue "", {}, (q) -> next(null, q)
      ]
      subscribe: ["queue", "exchange", (next, auto) ->
        auto.queue.bind(auto.exchange.name, "#")
        auto.queue.subscribe(pushMessage).addCallback (ok) -> next(null, ok)
      ]
    }, (err, results) ->
      auto = results
      done(err)
  # Close down the connection
  after () -> auto?.conn?.disconnect?()

  # Simple Publisher generation
  it "should generate Publisher instance than can publish", (done) ->
    r1 = "My-Exchange?a-dc/first.{route}.key"
    data = {route: "freakin", more: "todo"}
    routes.publisher auto.conn, r1, (err, pub) ->
      pub.publish [data], data, (e) ->
        return done(e) if e
        checkMessage()
    checkMessage = () ->
      if not (msg = messages.shift())
        return setTimeout(checkMessage, 10)
      msg.body.should.eql(data)
      msg.info.routingKey.should.equal("first.freakin.key")
      done()

  # Two Publishers should share exchange instance when params same
  it "should reuse Exchange instances with same params", (done) ->
    r1 = "My-Exchange?a-dc/first.{route}.key"
    r2 = "My-Exchange?ac-d/second.{route}.key"
    data = {route: "freakin", more: "todo"}
    async.auto {
      p1: (next) -> routes.publisher(auto.conn, r1, next)
      p2: (next) -> routes.publisher(auto.conn, r2, next)
    }, (err, results) ->
      (results.p1.exchange is results.p2.exchange).should.be.true
      done()

  # Two Publishers DONT share exchange instance when params differ
  it "should NOT reuse Exchange with different params", (done) ->
    r1 = "My-Exchange?a-dc/first.{route}.key"
    r2 = "My-Exchange?a-d/second.{route}.key?mp"
    data = {route: "freakin", more: "todo"}
    async.auto {
      p1: (next) -> routes.publisher(auto.conn, r1, next)
      p2: (next) -> routes.publisher(auto.conn, r2, next)
    }, (err, results) ->
      (results.p1.exchange is results.p2.exchange).should.be.false
      results.p1.publish [data], data, () ->
        pubcon.p1 = true
      results.p2.publish [data], data, {appId: "fake2"}, () ->
        pubcon.p2 = true
      checkMessages()
    pubcon = {p1: false, p2: false}
    checkMessages = () ->
      if messages.length isnt 2
        return setTimeout(checkMessages, 10)
      m1 = messages.shift()
      m2 = messages.shift()
      rk1 = m1.info.routingKey
      rks = ["first.freakin.key", "second.freakin.key"]
      (rks.indexOf(rk1) is -1).should.be.false
      rk2 = m2.info.routingKey
      (rks.indexOf(rk2) is -1).should.be.false
      (rk1 isnt rk2).should.be.true
      pubcon.p1.should.be.true
      pubcon.p2.should.be.true
      done()
