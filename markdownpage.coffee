{basename, dirname, join, normalize, relative} = require 'path'
async = require 'async'
fs = require 'fs'
marked = require 'marked'

AbstractPage = require './abstractpage'

module.exports = class MarkdownPage extends AbstractPage
    constructor: (parentDir, @srcFile) ->
        url = @srcFile
        file = basename url
        b = file.toLowerCase()
        if b.substr(-3) == '.md'
            @title = file.substring(0, b.length - 3)
            if b == 'readme.md'
                file = 'index.html'
            else
                file = "#{@title}.html"
            url = join dirname(url), file

        super parentDir, url

    src: (cb) ->
        srcFile = @srcFile
        async.waterfall [
            (cb) =>
                fs.readFile srcFile, 'utf-8', cb
            (content, cb) ->
                cb null, marked(content)
        ], cb
