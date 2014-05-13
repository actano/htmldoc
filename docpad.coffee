
URL_PREFIX_NAME = 'htmldoc'

URL_PREFIX = URL_PREFIX_NAME+'/'
ABS_URL_PREFIX = '/'+URL_PREFIX_NAME
URL_PATTERN = URL_PREFIX_NAME+'\\/'

{TOOLS,NODE_MODULES,HTMLDOC} = process.env
TOOLS ?= "../../../tools"
NODE_MODULES ?= "../../node_modules"
HTMLDOC ?= "../../build/htmldoc"

module.exports =
    pluginsPaths: [ NODE_MODULES ]
    srcPath: "#{HTMLDOC}/src"
    outPath: "#{HTMLDOC}/out"
    documentsPaths: [
        "#{TOOLS}/htmldoc/styles"
        '.'
    ]
    filesPaths: []
    layoutsPaths: [
        "#{TOOLS}/htmldoc/layouts"
    ]
    renderPasses: 2


    collections:
        features: () ->
            @getCollection("html")


    # Template Configuration
    templateData:
        site:
            title: "RPLAN"
        getTitleForPage: (page) ->
            title = page.title
            if !page.title
                title = page.url.replace(".html", "")
                title = (if title.substr(-1) is "/" then title.substr(0, title.length - 1) else title)
                title = title.split("/").pop()
            return title

        rootPath: (document)->
            result = ""
            len = document.url.split("/").length - 1
            result += "../" while len -= 1
            return result

    plugins:
        menu:
            menuOptions:
                skipEmpty: false
        livereload:
            enabled: false



