{basename, dirname, join, normalize, relative} = require 'path'
marked = require 'marked'

AbstractPage = require './abstractpage'
Commit = require './commit'

module.exports = class LogPage extends AbstractPage
    constructor: (parentDir) ->
        super parentDir, join parentDir.dir, 'commit.html'
        @title = 'Commits'

    src: (cb) ->
        Commit.commitLog @parentDir.dir, (err, content) ->
            if err?
                cb err
                return

            cb null, marked content
