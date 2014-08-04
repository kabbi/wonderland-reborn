styx = require "node-styx"
util = require "util"
rufus = require "rufus"
async = require "async"
pathUtils = require "path"

FidBasedStyxServer = require "./FidBasedStyxServer"

logger = rufus.getLogger "styx-server.tools.SimpleStyxServer"

StructFid = (@server, path) ->
    # Store some parameters for convenience
    @handlers = @server.config.handlers
    @path = path or "/"
    @data = {}
    # Every fid is dir by default
    @qid = @ensureCachedQid @path
    @entry = @handlers[@path]
    return
StructFid::pathExists = (path) ->
    for own entryPath, entry of @handlers
        if (entryPath.indexOf path) is 0
            return true
    return false
StructFid::ensureCachedQid = (path) ->
    @server.qidCache[path] ?=
        version: 0
        type: styx.QID_TYPE_DIR
        path: @server.lastQid++
StructFid::statByPath = (path) ->
    qid = @ensureCachedQid path
    entry = @handlers[path]
    # Adjust qid type
    if entry and not entry.directory
        qid.type = styx.QID_TYPE_FILE
    styxStat = 
        reservedType: 0
        reservedDev: 0
        qid: qid
        # TODO: we need or instead of plus here. Add some lib to do bigmath
        # TODO: make access rights configurable
        mode: 0o777 + if qid.type is styx.QID_TYPE_DIR then styx.DMDIR else 0
        # TODO: persist times
        lastAccessTime: 0
        lastModificationTime: 0
        # FIXME: why do we need 0 size for dirs here?
        # TODO: better calculate file size
        length: entry?.size or entry?.content?.length or 0
        name: pathUtils.basename path or "."
        ownerName: @server.userName or ""
        groupName: @server.userName or ""
        lastModifierName: ""
StructFid::walk = (pathEntries, callback) ->
    # No entries, just clone
    if not pathEntries.length
        return callback null, new StructFid(@server, @path), []
    # Resolve all the parts to the absolute paths
    pathEntries = pathEntries.map (entry, idx) => pathUtils.join @path, pathEntries[..idx]...
    # A quick hack here - just check the final path for existence
    [..., finalPath] = pathEntries
    return callback styx.ENOTFOUND unless @pathExists finalPath
    # Now populate the qids, and fire an answer
    qids = []
    for entry in pathEntries
        qids.push @ensureCachedQid entry
    callback null, new StructFid(@server, finalPath), qids
StructFid::open = (mode, callback) ->
    if mode & (styx.MODE_READ | styx.MODE_READ_WRITE) and (not @entry.content or not @entry.read)
        return callback styx.EPERM
    if mode & (styx.MODE_WRITE | styx.MODE_READ_WRITE) and not @entry.write
        return callback styx.EPERM
    @opened = true
    callback null
StructFid::read = (count, offset, callback) ->
    return callback styx.EPERM unless @entry
    if offset is 0 or not @cachedData
        @cachedData ?= @entry.content or @entry.read.call @
    # Do a bit of translation
    if typeof @cachedData is "string"
        @cachedData = new Buffer @cachedData, "utf8"
    callback null, @cachedData.slice offset, offset + count
StructFid::write = (data, offset, callback) ->
    return callback styx.EPERM unless @entry or @entry.write
    callback null, @entry.write.call @, data
StructFid::list = (callback) ->
    paths = {}
    pathLen = @path.length
    pathLen++ unless @path is "/"
    for own path, entry of @handlers
        # If the prefix matches our path, add it as dir
        if (path.indexOf @path) is 0
            path = path[pathLen..]
            path = path[..path.indexOf "/"]
            paths[pathUtils.join @path, path] = true if path
    callback null, Object.keys(paths).map (path) => @statByPath path
StructFid::stat = (callback) ->
    callback null, @statByPath @path
StructFid::clunk = (callback) ->
    @entry?.close?.call @
    callback()

SimpleStyxServer = module.exports = (@stream, @config) ->
    return new SimpleStyxServer(stream, config) unless @ instanceof SimpleStyxServer

    # Incremental qid.path counter
    @lastQid = 0
    @qidCache = {}

    # Base class creation
    @config.rootFid = new StructFid @
    FidBasedStyxServer.call @, stream, config

    return

util.inherits SimpleStyxServer, FidBasedStyxServer