{
    UnionStyxServer,
    SimpleStyxServer,
    pipeUtils
} = require "styx-server"
events = require "events"
rufus  = require "rufus"
util   = require "util"
net    = require "net"

config = require "./config"
logger = rufus.getLogger "modules.styxroot"

module.exports = StyxRoot = (@cheshire) ->
    events.EventEmitter.call @
    @name = "styxroot"
    @on "connected", =>
        @setupServer()
    return
util.inherits StyxRoot, events.EventEmitter

StyxRoot::setupServer = () ->

    handlers = 
        "/welcome":
            content: "Welcome to the Wonderland! Enter on your own risk\n"
        "/kill":
            write: -> 42

    [s1, s2] = pipeUtils.createPipe()
    @controlRoot = new SimpleStyxServer s2, handlers: handlers
    @server.addUnion "./cheshire", s1
    @cheshire.emit "styxroot.control-root.ready", @controlRoot

StyxRoot::init = (prevInstance, callback) ->
    callback = prevInstance unless callback
    server = net.createServer (client) =>
        if @server
            logger.error "Cannot handle several clients"
            client.end()
            return

        logger.debug "client connected"
        @cheshire.emit "styxroot.ready", @
        
        client.on "end", =>
            logger.debug "client disconnected"
            @server = null
        client.on "error", (error) =>
            logger.error "Some connection exception: #{error}"

        @server = new UnionStyxServer client
        @emit "connected", @server

    server.listen config.styx.port, config.styx.host, =>
        logger.debug "listening on #{config.styx.host}:#{config.styx.port}"
 
    callback null, @

StyxRoot::destroy = (callback) ->
    if @server
        @server.stream.end()
        @server?.destroy()
        delete @server
    @cheshire.emit "styxroot.finished", @
    callback null
