styx = require "node-styx"
util = require "util"
rufus = require "rufus"
events = require "events"
stream = require "stream"
async = require "async"
pathUtils = require "path"

logger = rufus.getLogger "styx-server.StyxServer"

StyxServer = module.exports = (@stream, @config) ->
    return new StyxServer() unless @ instanceof StyxServer
    events.EventEmitter.call @

    # Configuration
    @config = @config or {}

    # TODO: remove this
    @stream.on "data", (data) ->
        logger.debug "Received data dump: #{data.toString 'hex'}"

    # Start a styx protocol
    @stream = new styx.StyxStream @stream
    @stream.on "error", (err) ->
        logger.error "Stream error: ", err
        @emit "error", "Stream error: #{err}"

    # Answering logic
    @stream.on "data", (msg) =>
        logger.debug "Received", msg
        @emit "message", msg

util.inherits StyxServer, events.EventEmitter

StyxServer::answer = (toMsg, msg) ->
    msg.tag = toMsg.tag
    logger.debug "Sent", msg
    @stream.write msg