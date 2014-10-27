###
name: styxroot
###
{
    UnionStyxServer,
    SimpleStyxServer,
    FidBasedStyxServer,
    pipeUtils
} = require "styx-server"
rufus   = require "rufus"
util    = require "util"
net     = require "net"

config = require "./config"
logger = rufus.getLogger "modules.styxroot"

module.exports = StyxRoot = (@cheshire) ->
    # Empty constructor
    return

StyxRoot::setupServer = () ->

    handlers = 
        "/welcome":
            content: "Welcome to the Wonderland! Enter on your own risk\n"
        "/kill":
            write: -> 42

    [s1, s2] = pipeUtils.createPipe()
    @controlRoot = new SimpleStyxServer s2, handlers: handlers
    @server.addUnion "./cheshire", s1
    @cheshire.emit "/styxroot/control-root/ready", @controlRoot

StyxRoot::init = ->
    server = net.createServer (client) =>
        if @server
            logger.error "Cannot handle several clients"
            client.end()
            return

        logger.debug "client connected"
        @cheshire.emit "/styxroot/connected",
            client.remoteAddress, client.remotePort
        
        client.on "end", =>
            logger.debug "client disconnected"
            @server = null
        client.on "error", (error) =>
            logger.error "Some connection exception: #{error}"

        @server = new UnionStyxServer client
        @server.on "walk", (path) =>
            @cheshire.emit "/styxroot/walk", @server, path
        @setupServer()

    server.listen config.styx.port, config.styx.host, =>
        logger.debug "listening on #{config.styx.host}:#{config.styx.port}"

StyxRoot::destroy = ->
    if @server
        @server.stream.end()
        @server?.destroy()
        delete @server
    @cheshire.emit "/styxroot/finished"
