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
        @environment = new Codo.Environment()

    src: (cb) ->
        console.log "Generating API documentation for #{@parentDir.name}"
        @parseCoffeeFiles()
        cb null, @assembleHtml()

    parseCoffeeFiles: ->
        # don't consider underscore functions
        @environment.options['implicit-private'] = true

        for script in @getScriptFiles()
            @environment.readCoffee "#{@parentDir.dir}/#{script}"
        @environment.linkify()

        theme = new Theme @environment
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
        nav += @createLinkList 'Mixin List', @getMixinKeys()
        nav += @createLinkList 'Module List', @getFileKeys()
        nav += '</div>'
        return nav

    createLinkList: (title, keys) ->
        return '' if keys.length is 0
        list = "<h1>#{title}</h1><ul>"
        list += "<li><a href='##{key}'>#{key}</a></li>" for key in keys
        list += '</ul>'
        return list

    createPart: (key, html) ->
        "<div class='apidoc' id=#{key}><a href='#navigation'>top</a>#{html}</div>"

    getClassKeys: ->
        classes = []
        classes = klass.name for klass in @environment.allClasses()

    getMixinKeys: ->
        classes = []
        classes = mixin.name for mixin in @environment.allMixins()

    getFileKeys: ->
        files = []
        files = file.name for file in @environment.allFiles()

    createSeparator: ->
        '<br><hr><hr><br>'