pathUtils   = require "path"
async       = require "async"
rufus       = require "rufus"
yaml        = require "js-yaml"
util        = require "util"
fs          = require "fs"
_           = require "underscore"

SEPARATOR = "###"
logger = rufus.getLogger "modules.moduler"

module.exports = Moduler = (@cheshire) ->
    # Map module name to object
    @modules = {}
    # Map of modules that are waiting
    # for some dependency
    @unresolved = {}
    # Some helper to resolve dependencies
    @depsManager = new DependencyManager @
    return

Moduler::init = ->
    @loadLocalModules()

Moduler::loadLocalModule = (header, file) ->
    handler = require file
    header.handler = handler
    @loadModule header

Moduler::loadLocalModules = ->
    files = fs.readdirSync __dirname
    for file in files
        try
            continue if file is "moduler.coffee"
            logger.debug "trying to load #{file}"
            # We are using absolute paths everywhere
            file = __dirname + "/" + file
            # Don't load ourselves
            continue if file is __filename
            # Try to handle folder-cases
            file = @determineFileName file
            # Extract header
            code = fs.readFileSync(file).toString()
            header = @extractHeader code
            header = yaml.safeLoad header
            header = @fixHeader header, file
            @loadLocalModule header, file
        catch e
            logger.error "Failed to load module: #{e.toString()}"
    return

Moduler::loadModule = (module) ->
    if @modules[module.name] or @unresolved[module.name]
        logger.debug "module #{module.name} is already loaded"
        return
    if not @depsManager.isResolved module
        logger.debug "skipping #{module.name}, unmet dependencies found"
        @unresolved[module.name] = module
        return
    logger.debug "starting #{module.name}"
    module.handler = new module.handler @cheshire
    @modules[module.name] = module
    module.handler.init()
    @checkUnresolved()

Moduler::unloadModule = (module) ->
    # uninit module

Moduler::checkUnresolved = ->
    for own name, m of @unresolved
        continue unless @depsManager.isResolved m
        delete @unresolved[m.name]
        @loadModule m
    return

Moduler::checkResolved = (oldModule) ->
    # TODO: implement
    return

Moduler::determineFileName = (file) ->
    coffeeFile = file + ".coffee"
    if fs.existsSync coffeeFile
        return coffeeFile
    if fs.statSync(file).isDirectory
        return file + "/index.coffee"

Moduler::extractHeader = (code) ->
    startIndex = code.indexOf SEPARATOR
    endIndex = code.indexOf SEPARATOR, startIndex + SEPARATOR.length
    if startIndex is -1 or endIndex is -1
        throw new ModulerError "no header found"
    return code.substring startIndex + SEPARATOR.length, endIndex

Moduler::fixHeader = (header, file) ->
    if not header.name
        throw new ModulerError "no module name for #{file}"
    header.file = file
    header.deps ?= []
    header.emits ?= {}
    header.accepts ?= {}
    # Rename dependencies field for convenience
    header.deps = header.dependencies
    delete header.dependencies
    return header

DependencyManager = (@moduler) ->
    # Empty constructor
    return

DependencyManager::isResolved = (module) ->
    loaded = _.collect @moduler.modules, (m, name) -> name
    return _.difference(module.deps, loaded).length is 0

# FIXME: unused
DependencyManager::listResolvedBy = (module) ->
    loaded = _.collect @moduler.modules, (m, name) -> name
    loaded.push module.name
    logger.error loaded
    resolvedBy = []
    for name, m in @moduler.unresolved
        if _.difference(m.deps, loaded).length is 0
            resolvedBy.push name
    return resolvedBy

ModulerError = (@message) ->
    Error.captureStackTrace(this, this.constructor)
    @name = "ModulerError" # TODO: detect name
    return
util.inherits ModulerError, Error
