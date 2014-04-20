net = require "net"
readline = require "readline"
winston = require "winston"
winston.remove winston.transports.Console
winston.add winston.transports.Console, {colorize: true}
winston.level = 'verbose'
argv = (require "yargs").argv

StyxStream = require "../styx/stream"

host = argv.host or "localhost"
port = argv.port or 8124

startStyx = (target) ->
    socket = new StyxStream target
    socket.on "end", ->
        winston.verbose "Disconnected"
    socket.on "error", (error) ->
        winston.error error
    socket

startCli = (socket) ->

    rl = readline.createInterface
            input: process.stdin
            output: process.stdout

    rl.on "line", (line) ->
        winston.error "Data: #{(new Buffer line, 'utf-8').toString 'hex'}"
        return rl.prompt() unless line

        try
            msg = JSON.parse line
            winston.verbose "-> #{JSON.stringify msg}"
            socket.write msg
        catch e
            winston.error "Your input is not valid json: #{e}"
        rl.prompt()

    rl.on "close", ->
        socket.end()
        if argv.server
            server.close()

    socket.on "data", (msg) ->
        winston.verbose "<- #{JSON.stringify msg}"
    socket.on "end", ->
        rl.close()

    rl.setPrompt argv.prompt or "styx> "
    rl.prompt()

if argv.server
    started = false
    server = net.createServer (client) ->
        winston.verbose "Connection attempt from #{client.remoteAddress}"

        if started
            winston.error "Can only handle one client"
            client.end()

        started = true
        startCli startStyx client
    server.listen port, host, ->
        winston.verbose "Waiting for connection on #{host}:#{port}"
else
    socket = net.connect port, host, ->
        winston.verbose "Connected to #{host}:#{port}"
        startCli startStyx socket