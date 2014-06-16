{basename, dirname, join, normalize, relative} = require 'path'
marked = require 'marked'

AbstractPage = require './abstractpage'

module.exports = class IndexPage extends AbstractPage
    constructor: (parentDir) ->
        super parentDir, join parentDir.dir, 'index.html'
        @title = basename parentDir.name

    src: (cb) ->
        items = []
        for url, page of @parentDir.files
            if page.title?
                items.push "* [#{page.title}](#{url})"
        html = marked(items.join('\n'))
        cb null, html
