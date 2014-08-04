stream = require "stream"
rufus = require "rufus"
yargs = require "yargs"
repl = require "repl"
net = require "net"

SimpleStyxServer = require "../lib/SimpleStyxServer"

logger = rufus.getLogger "export"

argv = yargs.argv
host = argv.host or "127.0.0.1"
port = argv.port or 6666

r = repl.start "union>"
r.on "exit", ->
    server.close()

# The context here is 'fid' object
handlers =
    "/some/long/path":
        content: "Sample content"
    "/intro":
        read: ->
            "Hello, #{@server.userName}! The time now is: #{new Date()}"
    "/pastebin":
        write: (data) ->
            @data.userName = data
            data.length
        read: ->
            "Hello, #{@data.userName}"
    "/some/long/dir":
        directory: true

server = net.createServer (client) ->

    client.on "end", ->
        logger.verbose "Client disconnected"
    client.on "error", (error) ->
        logger.error "Some connection exception: #{error}"

    logger.info "New client connected: #{client.remoteAddress}"

    r.context.server = new SimpleStyxServer client, handlers: handlers

server.listen port, host, ->
    logger.info "Listening on #{host}:#{port}"
