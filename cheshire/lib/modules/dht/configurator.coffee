fs = require "fs"
config = require "./config"

if not fs.existsSync "./data/dht.json"
	# Fill in fake neighbours, just to make dht work
	# TODO: try to find transmissions, utorrent, etc peer list and use it
	data = config.template
	fs.writeFileSync "./data/dht.json", JSON.stringify data, null, 4

# FIXME: destroy this awful hack
process.env.KADOH_TRANSPORT = config.nodeConfig.transport