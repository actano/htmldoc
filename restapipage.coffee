{basename, dirname, join, normalize, relative} = require 'path'
AbstractPage = require './abstractpage'
Apidoc = require 'apidoc/lib/apidoc'

jade = require 'jade'
#template = require './restapi.jade'

###
    Uses apidoc to generate documentation page.
###
module.exports = class RestApiPage extends AbstractPage
    constructor: (@parentDir) ->
        super parentDir, join(parentDir.dir, 'restapi.html')
        @title = 'Rest API Documentation'

    src: (cb) ->
        data = Apidoc.getParsedData(@parentDir.dir)

        if data?
            path = join process.cwd(), 'tools', 'htmldoc', 'views', 'restapi.jade'

            cb null, jade.renderFile(path, data: data)
        else
            cb null

    parent: ->
         return @parentDir.index()
