{basename, dirname, join, normalize, relative} = require 'path'
fs = require 'fs'
async = require 'async'

IndexPage = require './indexpage'
LogPage = require './logpage'
MarkdownPage = require './markdownpage'
JSFile = require './jsfile'

base = process.cwd()
root = relative __dirname, base

throwError = (err) -> throw err if err?

module.exports = class Directory
    constructor: (@parentDir, @dir) ->
        @name = basename @dir
        @files = {}
        @children = {}
        @scripts = []
        new IndexPage @

        if @parentDir?
            new LogPage @

    index: ->
        @files['index.html']

    toString: ->
        @dir

    readDir: (cb) ->
        fs.readdir @dir, (err, files) =>
            cb err if err?

            subdirs = []
            for f in files
                if f.toLowerCase() == 'manifest.coffee'
                    docs = require(join root, @dir, f).documentation
                    if docs?
                        for f in docs
                            name = f.toLowerCase()
                            if name.substr(-3) == ".md"
                                new MarkdownPage @, join(@dir, f)
                            else if name.substr(-3) == ".js"
                                new JSFile @, join(@dir, f)
                            else
                                throw "Unsupported Documentation file: #{f}"
                    cb null, subdirs, (page for n, page of @files)
                    return

            fileQueue = async.queue (data, cb) ->
                    {dir, name} = data
                    file = join(dir.dir, name)
                    fs.stat file, (err, stats) ->
                        throw err if err?
                        if stats.isDirectory()
                            subdirs.push new Directory dir, file
                        cb()
                , 5

            fileQueue.drain = () =>
                cb null, subdirs, (page for n, page of @files)

            for f in files
                if f.substring(0, 1) == '.'
                    continue

                name = f.toLowerCase()
                if name == 'build' or name == 'node_modules'
                    continue

                if name.substr(-3) == ".md"
                    new MarkdownPage @, join(@dir, f)
                    continue

                fileQueue.push
                        dir: @
                        name: f
                    , throwError
