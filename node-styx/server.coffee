
net = require "net"
winston = require "winston"
winston.remove winston.transports.Console
winston.add winston.transports.Console, {colorize: true}
winston.level = 'debug'

StyxParser = require "./styx/parser"

server = net.createServer (client) ->
    parser = new StyxParser (msg) ->
        winston.info "Received styx message:", msg

    winston.verbose "New client connected: #{client.remoteAddress}"
    client.on "end", ->
        winston.verbose "Client disconnected"
    client.on "error", (error) ->
        winston.error "Some connection exception: #{error}"

    client.on "data", (data) ->
        winston.verbose "Processing data: #{data.toString 'hex'}"
        parser.write data

server.listen 8124, ->
    winston.info "Listening on port: 8124"