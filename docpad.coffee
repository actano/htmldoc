
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
        '.'
    ]
    filesPaths: []
    layoutsPaths: [  # default
        '../../../tools/htmldoc/layouts'
    ]
    collections:
        # For instance, this one will fetch in all documents that have pageOrder set within their meta data
        pages: (database) ->
            database.findAllLive(isPage: true)

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

        ###
        # topLevelDirectory can be the language (de, en)
        # subTree is optional and restricts the result for the given subdirectory
        # without the index.* of the subdirectory
        # opts and sort will be passed to docpad's databaseQueryEngine.findAllLive method
        #
        ###
        getCollectionFor: () ->

            @getDatabase().findAllLive({url:$startsWith:'/lib'}, [url:1])


        ###
        # creates and set a collection with the given name
        # for all files which are exist under the given topLevelDirectory (de)
        ###
        createCollectionFor: (topLevelDirectory, collectionName, opts, sort) ->
            collection = @getCollectionFor topLevelDirectory, null, opts, sort
            docpad.setCollection(collectionName, collection)



