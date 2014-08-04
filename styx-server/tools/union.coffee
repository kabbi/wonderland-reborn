stream = require "stream"
rufus = require "rufus"
yargs = require "yargs"
repl = require "repl"
net = require "net"

UnionStyxServer = require "../lib/UnionStyxServer"
ExportStyxServer = require "../lib/ExportStyxServer"
pipe = require "./pipe-utils"

logger = rufus.getLogger "export"

argv = yargs.argv
host = argv.host or "127.0.0.1"
port = argv.port or 6666

r = repl.start "union>"
r.on "exit", ->
    server.close()

serverId = ->
    id = 0
    -> id++
unionsIdGenerator = serverId()
createUnionExportStyxServer = (context) ->
    id = unionsIdGenerator()
    [s1, s2] = pipe.createPipe()
    context['export' + id] = new ExportStyxServer s2, exportPath: "."
    s1

server = net.createServer (client) ->

    client.on "end", ->
        logger.verbose "Client disconnected"
    client.on "error", (error) ->
        logger.error "Some connection exception: #{error}"

    logger.info "New client connected: #{client.remoteAddress}"

    r.context.server = new UnionStyxServer client
    r.context.UnionStyxServer = UnionStyxServer
    r.context.ExportStyxServer = ExportStyxServer

    r.context.server.addUnion "./some/long/path", createUnionExportStyxServer r.context
    r.context.server.addUnion "./some/another/path", createUnionExportStyxServer r.context
    r.context.server.addUnion "./some/folder", createUnionExportStyxServer r.context
    r.context.server.addUnion "./some/long/folder", createUnionExportStyxServer r.context

server.listen port, host, ->
    logger.info "Listening on #{host}:#{port}"
