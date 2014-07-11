{basename, dirname, join, normalize, relative} = require 'path'
AbstractPage = require './abstractpage'

###
    Dummy Page class used to insert a link to the actual rest api documentation
    page.
###
module.exports = class RestApiPage extends AbstractPage
    constructor: (@parentDir) ->
        super parentDir, join(parentDir.dir, 'rest', 'restapi.html')
        @title = 'Rest API Documentation'

    src: (cb) ->
        cb null, null

    parent: ->
         return @parentDir.index()
