###
name: styxclient
dependencies:
    - styxprovider
    - styxroot
    - dht
###
rufus  = require "rufus"
kadoh  = require "kadoh"
util   = require "util"
net    = require "net"

{util: {crypto}} = kadoh

logger = rufus.getLogger "modules.styxclient"

module.exports = StyxClient = (@cheshire) ->
    # Empty constructor
    return

StyxClient::init = ->
    @cheshire.on "/styxroot/walk", @handleWalk.bind @
    @cheshire.emit "/styxclient/ready"

StyxClient::destroy = ->
    # TODO: disconnect all unions
    @cheshire.emit "/styxclient/finished"

StyxClient::pathToKey = (path) ->
    crypto.digest.SHA1 path

StyxClient::handleWalk = (server, path) ->
    absPath = if path is "." then "/" else "/" + path
    logger.debug "walk to", absPath
    @cheshire.emit "/dht/get", (@pathToKey absPath), (values) =>
        return unless values
        logger.debug "found data for #{absPath}", values
        folders = values.map (entry) -> entry.value.name
        server.setIntermediate path, folders
        # TODO: connect the union, providing some encryption on demand

