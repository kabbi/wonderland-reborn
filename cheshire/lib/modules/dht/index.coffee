###
name: dht
dependencies:
    - styxroot
###
require "./configurator"
kadoh   = require "kadoh"
rufus   = require "rufus"
path    = require "path"
util    = require "util"
fs      = require "fs"

{
    logic: {KademliaNode},
    util: {crypto}
} = kadoh

logger = rufus.getLogger "modules.dht"

# Constants
SAVE_DHT_DATA_INTERVAL_MILLIS = 10 * 60 * 1000

module.exports = Dht = (@cheshire) ->
    # Config data always exists, configurator is managing it
    dhtData = JSON.parse fs.readFileSync "./data/dht.json"
    @config = require "./config"
    nodeConfig = @config.nodeConfig
    # FIXME: get rid of fake bootstrap node
    # Get bootstrap from saved state, or provide fake-one
    nodeConfig.bootstraps = dhtData.bootstrapNodes or ["127.0.0.1:1000"]
    @node = new KademliaNode dhtData.nodeId, nodeConfig
    return

Dht::init = (prevInstance, callback) ->
    @cheshire.on "/styxroot/control-root/ready", (server) =>
        logger.debug "adding dht interface to control root"

        server.rootFid.handlers["/dht/status"] =
            read: => "#{@node.getState()}\n"
        server.rootFid.handlers["/dht/peers/list.json"] =
            read: => JSON.stringify @node._routingTable.exports(), null, 4
        server.rootFid.handlers["/dht/peers/add"] = 
            write: (addr) => @node._routingTable.addPeer new kadoh.dht.BootstrapPeer addr
            read: -> "write node's adresses here"
        # TODO: finish dht rpc interface
        server.rootFid.handlers["/dht/ping"] = 
            write: -> @data.answer = "pinged"
            read: -> @data.answer or "write node id to ping it"
    @node.connect =>
        @node.join =>
            logger.debug "node joined"
            @cheshire.emit "/dht/joined"
        @saveDataTimer = setInterval (@saveDhtData.bind @),
            SAVE_DHT_DATA_INTERVAL_MILLIS
        @saveDhtData()
        logger.debug "node connected"
        @cheshire.emit "/dht/connected"
    @setupApi()

Dht::destroy = ->
    clearInterval @saveDataTimer
    @node.disconnect =>
        @cheshire.emit "/dht/finished"

Dht::setupApi = ->
    @cheshire.on "/dht/put", (key, value, callback) =>
        @node.put key, value, callback
    @cheshire.on "/dht/get", (key, callback) =>
        @node.get key, callback
    @cheshire.on "/dht/node/info", (callback) =>
        callback? id: @node.getID()

Dht::saveDhtData = ->
    logger.debug "saving dht state snapshot"
    # TODO: pick some good bootstrap nodes from our contacts
    nodeData = 
        routingTable: @node._routingTable.exports
            include_lastseen: true
            include_distance: true
        nodeId: @node.getID()
        bootstrapNodes: null
    fs.writeFileSync "./data/dht.json", JSON.stringify nodeData, null, 4

