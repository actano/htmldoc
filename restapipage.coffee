{basename, dirname, join, normalize, relative} = require 'path'
AbstractPage = require './abstractpage'
Apidoc = require 'apidoc/lib/apidoc'


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
            cb null, JSON.stringify data
        else
            cb null

    parent: ->
         return @parentDir.index()
