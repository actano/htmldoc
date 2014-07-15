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
        @title = 'Rest API Documentation'

    src: (cb) ->
        data = Apidoc.getParsedData(@parentDir.dir)

        if data?
            path = join process.cwd(), 'tools', 'htmldoc', 'views', 'restapi.jade'

            @_removeHtmlTags data

            cb null, jade.renderFile(path, data: data)
        else
            cb null

    parent: ->
         return @parentDir.index()

    _removeHtmlTags: (data) ->
        for route, i in data
            if route.type isnt ''
                if route.parameter?.fields?
                    for name, field of route.parameter.fields
                        for property, j in field
                            data[i].parameter.fields[name][j].description = data[i].parameter.fields[name][j].description.replace('<p>', '').replace('</p>', '')

                if route.success?.fields?
                    for name, field of route.success.fields
                        for property, j in field
                            data[i].success.fields[name][j].description = data[i].success.fields[name][j].description.replace('<p>', '').replace('</p>', '')

                if route.error?.fields?
                    for name, field of route.error.fields
                        for property, j in field
                            data[i].error.fields[name][j].description = data[i].error.fields[name][j].description.replace('<p>', '').replace('</p>', '')
