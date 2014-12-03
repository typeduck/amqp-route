# Utility for AMQP Message Routing

Describe AMQP exchange and routing keys in a compact way (and as
templates). Purpose is to allow compact (and external, e.g. via configuration
strings) declaration of AMQP Exchange and routing keys, and to create routing
key based on message data.

## Installation

    npm install amqp-route

## Basic Usage

Create a template with `require("amqp-route").template(tplString)`. Then make a
routing key by using `fill` method with data objects.

```javascript
var route = require("amqp-route").template("MyExchange/route.key.{str}")
route.exchange;            // "MyExchange"
route.fill({str: "foo"});  // "route.key.foo"
route.fill({});            // "route.key" (strips dots)
route.fill({skip: "here"}, {str: "hereIam"}) // fallback list of data objects
var route2 = require("amqp-route").template("route.key.{str}")
route2.exchange;           // "" (Exchange is optional)
```

## Exchange Options

Generate a subset of available options for
[node-amqp](https://github.com/postwait/node-amqp) `connection.exchange()`.

```javascript
var route = require("amqp-route").template("MyExchange?dc-a/{routingKey}")
route.exchangeOpts; // {durable: true, confirm: true, autoDelete: false}
```

Options are a single letter (to set to true), prefixed by a `-` (to set to
false).

- a: *autoDelete*
- c: *confirm*
- d: *durable*
- n: *noDeclare*
- p: *passive*

## Publishing Options

Generate a subset of available options for
[node-amqp](https://github.com/postwait/node-amqp) `exchange.publish()`.

```javascript
var route = require("amqp-route").template("{routingKey}?mip")
route.pubOpts; // {mandatory: true, immediate: true, deliveryMode: 2}
```

Simlar to Exchange Options (single letter, optional `-`). The exception is `p`
(for "persistent", which sets `deliveryMode`.

- m: *mandatory*
- i: *immediate*
- p: *deliveryMode*
  - "p" sets "deliveryMode=2" (persistent)
  - "-p" sets "deliveryMode=1" (non-persistent)

## Template

Template object returned from ```require("amqp-route").template()```:

- `exchange`: exchange name
- `exchangeOpts`: parsed options suitable for
  [node-amqp](https://github.com/postwait/node-amqp) `connection.exchange()`
- `template`: routing key template used in (template.fill())[#template-fill]
- `pubOpts`: publishing options suitable for
  [node-amqp](https://github.com/postwait/node-amqp) `exchange.publish()`

### template.fill(object[, object...])

Creates a routing key for some data by replacing all strings in curly braces
with value from the first object having that property. Any leading, trailing, or
double work separators (dots) are removed.

```javascript
var route = require("amqp-route").template("{a}.{b}.{c}.{d}")
var rk = route.fill({a: "A"}); // "A"
rk = route.fill({a: "A"}, {a: "X", c: "C"}); // "A.C"
rk = route.fill({a: "A", b: "B", d: "D, c: null}); // "A.B.D"
```

## Publisher

Publisher builds on Template, setting up an Exchange with options and *always*
calling the callback, even when the Exchange is not in confirm mode. It also
uses the publishing options from the Template.

```javascript
var amqpRoute = require("amqp-route");
var amqpConn = require("amqp").createConnection(connectionOpts);
// create a publisher in confirm mode, durable and no autoDelete
amqpRoute.publisher(amqpConn, "My-Exchange?-acd/{routing}.{template}", function(err, pub){
  var routingKeySources = [{routing: "sample"}, {template: "key"}];
  var message = {important: "data"};
  pub.publish(routingKeySources, message, function(err){
    // message published with routing key "sample.key", confirm mode
    // when NOT using confirm mode, this is called via process.nextTick()
  });
});
```

Additionally, you can include further Exchange options.

```javascript
var tpl = "My-Exchange?-acd/{routing}.{template}";
amqpRoute.publisher(amqpConn, tpl, {type: "direct"}, function(err, pub){
  // now we are using a Direct exchange instead of topic
});
```

### publisher.publish(routeFillers, message[, pubOpts[, callback]])

Publish a message, additional options are passed to
[node-amqp](https://github.com/postwait/node-amqp) `exchange.publish()` and any
passed callback will be called regardless of confirm mode.

`routeFillers` is an array of sources to create routing key from Template. It
corresponds to arguments passed in `Template.fill()`.
