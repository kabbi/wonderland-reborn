###
name: styxprovider
dependencies:
    - styxroot
    - dht
###
pathUtil = require "path"
server   = require "styx-server"
rufus    = require "rufus"
kadoh    = require "kadoh"
styx     = require "node-styx"
util     = require "util"
net      = require "net"
fs       = require "fs"

{util: {crypto}} = kadoh

logger = rufus.getLogger "modules.styxprovider"
EXPORTS_FILE_PATH = "./data/exports.json"

module.exports = StyxProvider = (@cheshire) ->
    @name = "styxprovider"
    @cheshire.on "/styxprovider/exported", =>
        @saveExports()
    return

StyxProvider::init = (prevInstance, callback) ->
    @cheshire.on "/styxroot/control-root/ready", (server) =>
        @setupControlRoot server.rootFid.handlers
        @controlRoot = server

    @internalExports =
        export: @createExportServer
        proxy: @createProxyServer
        internal: @createControlRootServer
    @exportsMap = {}

    # Publish onto dht
    @cheshire.on "/styxprovider/exported", (e) =>
        @cheshire.emit "/dht/node/info", (nodeId) =>
            uid = crypto.digest.SHA1 "#{e.path}:#{e.spec}"
            key = crypto.digest.SHA1 pathUtil.dirname e.path
            value =
                name: pathUtil.basename e.path
                provider: nodeId
                target: uid
            value = JSON.stringify value
            # Publish server itself
            @cheshire.emit "/dht/put", key, value, (key, storedCount) =>
                logger.debug "publishing exported server on '#{e.path}'
                    to #{storedCount} peers in dht"
            # Publish helper dummy folder-like structures
            components = (e.path.split "/")[1...-1] # strip begin and end
            currentPath = "/"
            for component in components
                key = crypto.digest.SHA1 currentPath
                @cheshire.emit "/dht/put", key, dummy: true, name: component
                logger.debug "dummy at #{currentPath} -> #{component}"
                currentPath = pathUtil.join currentPath, component

    # Load exports
    process.nextTick =>
        exports = JSON.parse fs.readFileSync EXPORTS_FILE_PATH
        for own path, spec of exports
            @addExporterServer path, spec

    @cheshire.emit "/styxprovider/ready"

StyxProvider::destroy = (callback) ->
    callback null

StyxProvider::saveExports = ->
    logger.debug "saving exports"
    toExport = {}
    for own path, entry of @exportsMap
        toExport[path] = entry.spec
    fs.writeFileSync EXPORTS_FILE_PATH, JSON.stringify toExport, null, 4

StyxProvider::pathToKey = (path) ->
    crypto.digest.SHA1 path

StyxProvider::addExporterServer = (path, serverSpec) ->
    if @exportsMap[path]
        logger.debug "Not adding #{path} because already added"
        return
    # We have several ways to add the server:
    #     1. build-in, is loder from this module, and provides
    #     some basic servers, like export, proxy, internal, etc
    #     2. by absolute path - require it and load, it's used
    #     from local instance host's fs
    #     3. by absolute path in wonderland - is loaded and started
    #     directly from some place in wonderland
    # We assume, that loaded module contains exactly one class,
    # that overrides StyxServer, accepts stream as it's first cons-
    # tructor argument, etc
    logger.info "Adding server #{serverSpec} on #{path}"
    if serverSpec[0] is "/"
        logger.warn "Sorry, don't currently support external or wonderland exports"
    else
        [module, args...] = serverSpec.split " "
        return logger.error "Don't know, how to create export", module unless @internalExports[module]
        
        [interceptEnd, serverEnd] = server.pipeUtils.createPipe()
        styxServer = @internalExports[module].call @, serverEnd, args
        exporter = new StyxServerExporter interceptEnd

        @exportsMap[path] =
            path: path
            spec: serverSpec
            server: styxServer
            exporter: exporter
        @cheshire.emit "/styxprovider/exported", @exportsMap[path]

StyxProvider::setupControlRoot = (handlers) ->
    logger.debug "adding exports interface to control root"
    handlers["/exports/list"] =
        read: =>
            """
            List of servers, exported by us:
            [currently empty]

            """
    handlers["/exports/add"] =
        write: (data) =>
            data = data.toString("utf8").trim()
            spacePos = data.indexOf " "
            return if spacePos is -1

            path = data[...spacePos]
            serverSpec = data[spacePos+1...]
            return unless path and serverSpec

            @addExporterServer path, serverSpec
            return data.length
        read: =>
            "write <path> <server> to export it\n"

StyxProvider::createExportServer = (stream, args) ->
    return unless args.length
    # FIXME: We need something more cross-platform here
    userHome = process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE
    args[0] = args[0].replace "~", userHome
    new server.ExportStyxServer stream, exportPath: args[0]

# The class that does all the export work

StyxServerExporter = (@serverStream) ->
    @serverStream = new styx.StyxStream serverStream
    @serverStream.on "data", (msg) ->
        @answerMap[msg.tag]?.call msg
    # Track local fid usage
    @fidsMap = {}
    @answerMap = {}

StyxServerExporter::sendMessage = (msg, callback) ->
    msg.tag ?= @obtainTag()
    @answerMap[msg.tag] = callback
    @serverStream.write msg

StyxServerExporter::obtainNewExport = ->
    [externalStream, inputStream] = server.pipeUtils.createPipe()
    inputStream = new styx.StyxStream inputStream
    inputStream.on "data", (msg) =>
        # TODO: translate messages
        @sendMessage msg, (answer) =>
            inputStream.write answer
    return externalStream

StyxServerExporter::obtainTag = ->
    for i in [0..styx.MAX_TAG]
        return i unless @answerMap[i]
    # TODO: handle no tags situation
    throw new Error "see todo above"

StyxServerExporter::obtainFid = ->
    # TODO: implement