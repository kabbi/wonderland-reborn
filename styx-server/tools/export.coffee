rufus = require "rufus"
yargs = require "yargs"
net = require "net"

ExportStyxServer = require "../lib/ExportStyxServer"

logger = rufus.getLogger "export"

argv = yargs.argv
path = argv.path or "."
host = argv.host or "127.0.0.1"
port = argv.port or 6666

server = net.createServer (client) ->

    client.on "end", ->
        logger.verbose "Client disconnected"
    client.on "error", (error) ->
        logger.error "Some connection exception: #{error}"

    logger.info "New client connected: #{client.remoteAddress}"
    logger.info "Exporting", path

    server = new ExportStyxServer client, exportPath: path

server.listen port, host, ->
    logger.info "Listening on #{host}:#{port}"