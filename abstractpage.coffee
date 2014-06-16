{basename, dirname, join, normalize, relative} = require 'path'
async = require 'async'

title = 'RPLAN - Developer Documentation'

# Order: Indexfiles, Title (locale), Filename

comparePages = (a,b) ->
    aindex = 'index.html' == basename a.url
    bindex = 'index.html' == basename b.url
    return -1 if aindex && !bindex
    return 1 if bindex && !aindex
    if a.title? && b.title?
        result = a.title.localeCompare b.title
        return result unless result == 0
    else
        return -1 if !b.title?
        return 1 if !a.title?

    return a.url.localeCompare b.url

module.exports = class AbstractPage
    constructor: (@parentDir, @url) ->
        @file = basename @url
        @parentDir.files[@file] = @

    src: (cb) ->
        cb new Error

    toString: ->
        return @url

    navigation: () ->
        path = @path()
        return ((p.treeChildren().sort comparePages) for p in path)

    templateData: (path, navigation, cb) ->
        dir = @parentDir.dir
        siblings = []
        for name, p of @parentDir.files
            siblings.push p if p.title?
        siblings.sort comparePages

        data = {
            page: @
            navigation
            root: path[0]
            siblings
            title

            inpath: (url) ->
                for x in path
                    return true if url == x.url
                return false

            relative: (url) ->
                relative dir, url
        }

        jobs = []
        for s in @parentDir.scripts
            jobs.push (cb) ->
                s.src cb

        async.parallel jobs, () ->
            data.scripts = arguments[1]
            cb null, data

    parent: ->
        unless @file == 'index.html'
            return @parentDir.index()

        return null unless @parentDir.parentDir
        return @parentDir.parentDir.index()

    path: ->
        parent = @parent()
        return [@] unless parent?
        result = parent.path()
        result.push @
        return result

module.exports.comparePages = comparePages