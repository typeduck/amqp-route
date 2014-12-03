###############################################################################
# AMQP Data Routing Testing
###############################################################################

require("should")
routes = require("./index")

describe "amqp-route", () ->
  
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
