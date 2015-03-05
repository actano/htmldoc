{basename, dirname, join, normalize, relative} = require 'path'
jade = require 'jade'

AbstractPage = require './abstractpage'
Apidoc = require 'apidoc/lib/apidoc'

###
    Uses apidoc to generate documentation page.
###
module.exports = class RestApiPage extends AbstractPage
    constructor: (@parentDir) ->
        super parentDir, join(parentDir.dir, 'restapi.html')
        @title = 'REST API Documentation'

    src: (cb) ->
        console.log "Generating REST API documentation for #{@parentDir.name}"

        data = Apidoc.getParsedData(@parentDir.dir)

        if data?
            path = join __dirname, 'views', 'restapi.jade'

            cb null, jade.renderFile(path, data: data)
        else
            cb null

    parent: ->
         return @parentDir.index()
