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
    @startModules()
    @startCli() if yargs.argv.cli
    return
util.inherits Cheshire, events.EventEmitter

Cheshire::startModules = ->
    logger.debug "starting modules"
    Moduler = require "./modules/moduler"
    @moduler = new Moduler @
    @moduler.init()

Cheshire::startCli = ->
    repl = require "repl"
    r = repl.start
        prompt: "cheshire>"
    # TODO: correct cheshire shutdown
    r.on "exit", -> process.exit()
    r.context.cheshire = @
