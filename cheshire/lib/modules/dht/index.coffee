require "./configurator"
events = require "events"
kadoh  = require "kadoh"
rufus  = require "rufus"
path   = require "path"
util   = require "util"
fs     = require "fs"

{
    logic: {KademliaNode},
    util: {crypto}
} = kadoh

logger = rufus.getLogger "modules.dht"

# Constants
SAVE_DHT_DATA_INTERVAL_MILLIS = 10 * 60 * 1000

module.exports = Dht = (@cheshire) ->
    events.EventEmitter.call @
    @name = "dht"
    # Config data always exists, configurator is managing it
    dhtData = JSON.parse fs.readFileSync "./data/dht.json"
    @config = require "./config"
    nodeConfig = @config.nodeConfig
    # FIXME: get rid of fake bootstrap node
    # Get bootstrap from saved state, or provide fake-one
    nodeConfig.bootstraps = dhtData.bootstrapNodes or ["127.0.0.1:1000"]
    @node = new KademliaNode dhtData.nodeId, nodeConfig
    return
util.inherits Dht, events.EventEmitter

Dht::init = (prevInstance, callback) ->
    callback = prevInstance unless callback
    @cheshire.on "styxroot.control-root.ready", (server) =>
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
    # TODO: move to distrinct module
    @cheshire.on "styxprovider.exported", (e) =>
        uid = crypto.digest.SHA1 "#{e.path}:#{e.spec}"
        key = crypto.digest.SHA1 e.path
        value =
            provider: @node.getID()
            target: uid
        value = JSON.stringify value
        # Publish server itself
        @node.put key, value, (key, storedCount) =>
            logger.debug "publishing exported server on '#{e.path}'
                to #{storedCount} peers in dht"
        # Publish helper dummy folder-like structures
        components = (e.path.split "/")[...-1] # strip last component
        components = components.map (entry, idx) => path.join "/", components[..idx]...
        for component in components
            key = crypto.digest.SHA1 component
            @node.put key, dummy: true
    @node.connect =>
        @node.join -> logger.debug "node joined"
        @saveDataTimer = setInterval (@saveDhtData.bind @),
            SAVE_DHT_DATA_INTERVAL_MILLIS
        @saveDhtData()
        logger.debug "node connected"
        @cheshire.emit "dht.ready", @
        callback null, @

Dht::destroy = (callback) ->
    clearInterval @saveDataTimer
    @node.disconnect =>
        @cheshire.emit "dht.finished", @
        callback null

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

