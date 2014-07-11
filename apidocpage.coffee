{basename, dirname, join, normalize, relative} = require 'path'
Codo = require 'codo'
Theme = require 'codo/themes/default/lib/theme'

AbstractPage = require './abstractpage'

###
    This class uses Codo for parsing the CoffeeScript source files and puts the
    resulting html texts together to a single file called apidoc.html.
###
module.exports = class ApiDocPage extends AbstractPage
    constructor: (@parentDir, @manifest) ->
        super parentDir, join parentDir.dir, 'apidoc.html'
        @title = 'API Documentation'

    src: (cb) ->
        @parseCoffeeFiles()
        cb null, @assembleHtml()

    parseCoffeeFiles: ->
        # the following functions are needed for overriding the original Codo render functions
        parts = {}
        customRender = (template, context = {}, filename = '') ->
            html = @JST[template](context)
            if filename.length > 0
                # the entity name is either a class name or a file path
                parts[context.entity.name] = html
            return html
        renderClasses = ->
            for klass in @environment.allClasses()
                @render 'class', @pathFor('class', klass), {entity: klass}
        renderFiles = ->
            for file in @environment.allFiles()
                @render 'file', @pathFor('file', file), {entity: file}

        environment = new Codo.Environment()
        # don't consider underscore functions
        environment.options['implicit-private'] = true
        for script in @getScriptFiles()
            environment.readCoffee "#{@parentDir.dir}/#{script}"
        environment.linkify()

        theme = new Theme environment
        theme.templater.render = customRender
        theme.renderClasses = renderClasses
        theme.renderClasses()
        theme.renderFiles = renderFiles
        theme.renderFiles()

        @docParts = parts
        return

    getScriptFiles: ->
        scripts = @manifest.client?.scripts or []
        if @manifest.server?.scripts?.files?
            scripts = scripts.concat @manifest.server?.scripts?.files
        # only coffee script files can be processed
        return scripts.filter (script) ->
            script.indexOf('.coffee') isnt -1

    assembleHtml: ->
        return if @docParts is {}
        output = @createLinkList 'Class List', @getClassKeys()
        output += @createLinkList 'File List', @getFileKeys()
        for key, html of @docParts
            output += @createSeparator()
            output += @createPart key, html
        return output

    createLinkList: (title, keys) ->
        list = "<h1>#{title}</h1><ul>"
        list += "<li><a href='##{key}'>#{key}</a></li>" for key in keys
        list += '</ul>'
        return list

    createPart: (key, html) ->
        "<div class='apidoc' id=#{key}>#{@correctClassLinks html}</div>"

    # TODO Works only for internal classes of a feature. How to deal with external class links?
    correctClassLinks: (html) ->
        for className in @getClassKeys()
            # replace the original class link by an id reference
            regex = new RegExp "href=\'[\.\.\/]*class\/#{className}\.html\'", 'g'
            html = html.replace regex, "href='##{className}'"
        return html

    getClassKeys: ->
        key for key in Object.keys @docParts when key.indexOf('/') is -1

    getFileKeys: ->
        key for key in Object.keys @docParts when key.indexOf('/') isnt -1

    createSeparator: ->
        '<br><hr><hr><br>'