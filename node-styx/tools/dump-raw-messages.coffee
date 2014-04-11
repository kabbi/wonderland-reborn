
net = require "net"
winston = require "winston"
winston.remove winston.transports.Console
winston.add winston.transports.Console, {colorize: true}
winston.level = 'verbose'
argv = (require "yargs").argv

server = net.createServer (client) ->

    winston.verbose "New client connected: #{client.remoteAddress}"

    client.on "end", ->
        winston.verbose "Client disconnected"
    client.on "error", (error) ->
        winston.error "Some connection exception: #{error}"

    client.on "data", (data) ->
        winston.verbose "Message data: #{data.toString 'hex'}"

port = argv.port or 8124
server.listen port, ->
    winston.info "Listening on port: #{port}"