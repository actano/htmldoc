
URL_PREFIX_NAME = 'htmldoc'

URL_PREFIX = URL_PREFIX_NAME+'/'
ABS_URL_PREFIX = '/'+URL_PREFIX_NAME
URL_PATTERN = URL_PREFIX_NAME+'\\/'


module.exports =
    pluginsPaths: [
        '../../node_modules'
    ]
    srcPath: '../../build/htmldoc/src'
    outPath: '../../build/htmldoc/out'
    documentsPaths: [
        '../../../tools/htmldoc/styles'
        '.'
    ]
    filesPaths: []
    layoutsPaths: [  # default
        '../../../tools/htmldoc/layouts'
    ]
    renderPasses: 2  # default


    collections:
        features: (database) ->
            database.findAllLive({
                    relativeOutDirPath:
                        $startsWith: 'lib/'
                }
                [url: 1]
            )


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



    plugins:
        menu:
            menuOptions:
                skipEmpty: false



