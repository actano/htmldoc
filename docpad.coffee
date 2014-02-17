
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
    templateData:  # example

        # Specify some site properties
        site:

            # The default title of our website
            title: "RPLAN"

            # The website description (for SEO)
            description: """
                When your website appears in search results in say Google, the text here will be shown underneath your website's title.
                """

            # The website keywords (for SEO) separated by commas
            keywords: """
                place, your, website, keywoards, here, keep, them, related, to, the, content, of, your, website
                """
        getTitleForPage: (page) ->
            title = page.title
            if !page.title
                title = page.url.replace(".html", "")
                title = (if title.substr(-1) is "/" then title.substr(0, title.length - 1) else title)
                title = title.split("/").pop()
                if title == "lib" then title = "Features"
            return title



    plugins:
        menu:
            menuOptions:
                optimize: false
                skipEmpty: false



