events = require "events"
yargs  = require "yargs"
async  = require "async"
rufus  = require "rufus"
util   = require "util"
fs     = require "fs"

rufus.config require "./rufus-config"
logger = rufus.getLogger "cheshire"
rufus.console()

module.exports = Cheshire = ->
    events.EventEmitter.call @
    @on "init-finish", =>
        logger.info "Wheeeeeee! Welcome to the Wonderland!"
    @on "finished", =>
        logger.info "One does not simply stop Cheshire"
    @modules = {}
    @startModules()
    @startCli() if yargs.argv.cli
    return
util.inherits Cheshire, events.EventEmitter

Cheshire::startModules = ->
    logger.debug "starting modules"
    fs.readdir "./lib/modules", (err, files) =>
        return logger.error "Cannot start modules", err unless files
        logger.debug "found module #{file}" for file in files

        modules = (new (require "./modules/#{file}")(@) for file in files)
        @modules[module.name] = module for module in modules
        async.each modules, ((module, callback) ->
            module.init callback
        ), => @emit "init-finish"

Cheshire::startCli = ->
    repl = require "repl"
    r = repl.start
        prompt: "cheshire>"
    # TODO: correct cheshire shutdown
    r.on "exit", -> process.exit()
    r.context.cheshire = @
