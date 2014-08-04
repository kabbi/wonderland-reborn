fs = require "fs"
styx = require "node-styx"
util = require "util"
rufus = require "rufus"
async = require "async"
pathUtils = require "path"

FidBasedStyxServer = require "./FidBasedStyxServer"

logger = rufus.getLogger "styx-server.tools.Export2StyxServer"

translateError = (err) ->
    return undefined unless err
    errorCodes = 
        ENOENT: styx.ENOTFOUND
    errorCodes[err.code] or err.code or err

ExportFid = (@server, @path, callback) ->
    # Static map to transform styx mode to fs flags
    # TODO: better flags management
    @modeToFlags = {}
    @modeToFlags[styx.MODE_READ] = "r"
    @modeToFlags[styx.MODE_WRITE] = "w"
    @modeToFlags[styx.MODE_READ_WRITE] = "r+"
    # Check access violations
    relativePath = pathUtils.relative @server.rootPath, @path
    if (relativePath.indexOf "..") isnt -1
        # This shouldn't happen during normal operation
        return callback "array index out of bounds"
    # Cache stats
    fs.stat @path, (err, stat) =>
        return callback translateError err unless stat
        @stats = @statToStyx stat, @path
        @qid = @stats.qid
        @ready = true
        callback()
    return
ExportFid::qidTypeByStat = (stat) ->
    # TODO: add more quid types
    if stat.isDirectory() then styx.QID_TYPE_DIR else styx.QID_TYPE_FILE
ExportFid::statToStyx = (stat, path) ->
    styxStat = 
        reservedType: 0
        reservedDev: 0
        qid:
            version: 0
            path: stat.ino
            type: @qidTypeByStat stat
        # TODO: we need or instead of plus here. Add some lib to do bigmath
        mode: stat.mode + if stat.isDirectory() then styx.DMDIR else 0
        lastAccessTime: stat.atime.getTime() // 1000
        lastModificationTime: stat.mtime.getTime() // 1000
        # FIXME: why do we need 0 size for dirs here?
        length: if stat.isDirectory() then 0 else stat.size
        name: pathUtils.basename path
        ownerName: @server.userName or ""
        groupName: @server.userName or ""
        lastModifierName: ""
ExportFid::walk = (pathEntries, callback) ->
    # No entries, just clone
    if not pathEntries.length
        newFid = new ExportFid @server, @path, (err) =>
            return callback (translateError err), newFid, []
        return
    # Resolve all the parts to the absolute paths
    pathEntries = pathEntries.map (entry, idx) => pathUtils.join @path, pathEntries[..idx]...
    async.map pathEntries, fs.stat, (err, stats) =>
        return callback translateError err if err
        qids = stats.map (stat, idx) => (@statToStyx stat, pathEntries[idx]).qid
        [..., finalPath] = pathEntries
        newFid = new ExportFid @server, finalPath, (err) =>
            callback (translateError err), newFid, qids
ExportFid::open = (mode, callback) ->
    mode = @modeToFlags[mode]
    fs.open @path, mode, (err, fd) =>
        if not err
            @opened = true
            @fd = fd
        callback translateError err
ExportFid::read = (count, offset, callback) ->
    buffer = new Buffer count
    fs.read @fd, buffer, 0, count, offset, (err, bytesRead, buffer) =>
        return callback translateError err unless buffer
        # Crop the returned buffer if bytesRead is lower then needed
        buffer = buffer.slice 0, bytesRead unless bytesRead is count
        callback (translateError err), buffer
ExportFid::write = (data, offset, callback) ->
    fs.write @fd, data, offset, data.length, offset, (err, written, buffer) =>
        callback err, written
ExportFid::list = (callback) ->
    fs.readdir @path, (err, files) =>
        return callback translateError err unless files
        # Translate paths
        files = files.map (file) => pathUtils.join @path, file
        async.map files, fs.stat, (err, stats) =>
            return callback translateError err unless stats
            # Translate stats
            stats = stats.map (stat, idx) => @statToStyx stat, files[idx]
            callback null, stats
ExportFid::stat = (callback) ->
    callback null, @stats
ExportFid::clunk = (callback) ->
    return callback null unless @fd?
    fs.close @fd, (err) =>
        callback translateError err

ExportStyxServer = module.exports = (@stream, @config) ->
    return new ExportStyxServer(stream, config) unless @ instanceof ExportStyxServer

    # The path we are exporting
    @rootPath = pathUtils.resolve config.exportPath

    # Base class creation
    @config.rootFid = new ExportFid @, @rootPath, (err) =>
        throw new Error "cannot stat root path, #{err}" if err
        FidBasedStyxServer.call @, stream, config

    return

util.inherits ExportStyxServer, FidBasedStyxServer