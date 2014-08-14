events = require "events"
rufus  = require "rufus"
kadoh  = require "kadoh"
util   = require "util"
net    = require "net"

{util: {crypto}} = kadoh

logger = rufus.getLogger "modules.styxclient"

module.exports = StyxClient = (@cheshire) ->
    events.EventEmitter.call @
    @name = "styxclient"
    return
util.inherits StyxClient, events.EventEmitter

StyxClient::init = (prevInstance, callback) ->
    callback = prevInstance unless callback
    @cheshire.on "dht.ready", (dht) =>
        @node = dht.node
    @cheshire.on "styx-root.ready", (styxroot) =>
        @styxroot = styxroot
        @styxRootReady()
    @cheshire.emit "styxclient.ready", @
    callback null, @

StyxClient::destroy = (callback) ->
    # TODO: disconnect all unions
    @cheshire.emit "styxclient.finished", @
    callback null

StyxClient::pathToKey = (path) ->
    crypto.digest.SHA1 path

StyxClient::styxRootReady = () ->
    @styxroot.on "walk", (path) =>
        path = "/" if path is "."
        logger.debug "walk to", path
        @node.get (@pathToKey path), (value) =>
            return unless value
            logger.debug "found data for #{path}"
            # TODO: connect the union, providing some encryption on demand

