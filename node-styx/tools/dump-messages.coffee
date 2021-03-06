
net = require "net"
winston = require "winston"
winston.remove winston.transports.Console
winston.add winston.transports.Console, {colorize: true}
winston.level = 'verbose'
argv = (require "yargs").argv

StyxParser = require "../styx/parser"

server = net.createServer (client) ->

    parser = new StyxParser (msg) ->
        winston.verbose "Styx message received: #{JSON.stringify msg}"
    client.pipe parser
    
    winston.verbose "New client connected: #{client.remoteAddress}"

    client.on "end", ->
        winston.verbose "Client disconnected"
    client.on "error", (error) ->
        winston.error "Some connection exception: #{error}"

port = argv.port or 8124
server.listen port, ->
    winston.info "Listening on port: #{port}"