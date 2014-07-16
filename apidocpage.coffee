{basename, dirname, join, normalize, relative} = require 'path'
Codo = require 'codo'
Theme = require './codo/defaultTheme/lib/theme'

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
        console.log "Generating API documentation for #{@parentDir.name}"
        @parseCoffeeFiles()
        cb null, @assembleHtml()

    parseCoffeeFiles: ->
        environment = new Codo.Environment()

        # don't consider underscore functions
        environment.options['implicit-private'] = true

        for script in @getScriptFiles()
            environment.readCoffee "#{@parentDir.dir}/#{script}"
        environment.linkify()

        theme = new Theme environment
        theme.compile()

        @docParts = theme.getOutput()
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
        output = @createNavigation()
        for key, html of @docParts
            output += @createSeparator()
            output += @createPart key, html
        return output

    createNavigation: ->
        nav = "<div id='navigation'>"
        nav += @createLinkList 'Class List', @getClassKeys()
        nav += @createLinkList 'Module List', @getFileKeys()
        nav += '</div>'
        return nav

    createLinkList: (title, keys) ->
        list = "<h1>#{title}</h1><ul>"
        list += "<li><a href='##{key}'>#{key}</a></li>" for key in keys
        list += '</ul>'
        return list

    createPart: (key, html) ->
        "<div class='apidoc' id=#{key}><a href='#navigation'>top</a>#{@correctClassLinks html}</div>"

    # TODO Works only for internal classes of a feature. How to deal with external class links?
    # TODO: move this logic to theme.coffee#pathFor and templates
    # TODO: fix links and overview for mixins
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