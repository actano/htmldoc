{basename, dirname, join, normalize, relative} = require 'path'
fs = require 'fs'
async = require 'async'

childProcess = require 'child_process'
IndexPage = require './indexpage'
LogPage = require './logpage'
ApiDocPage = require './apidocpage'
RestApiPage = require './restapipage'
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

    # TODO: Hack to work around the way htmldoc.coffee works:
    # Currently there is the assumption that each Page class generates the content
    # of the corresponding html file, but in the case of the 'apidoc' utility
    # the html file will be generated directly by the tool and put into the filesystem.
    _generateRestDocumentation: (cb) ->
        currentDir = join base, @dir
        outputDir = join base, 'build', 'htmldoc', @dir, 'rest'
        templateDir = join base, 'tools', 'htmldoc', 'apidoc-template'

        command = "apidoc"
        args = ["-i", currentDir, "-o", outputDir, "-t", templateDir]
        apiDocProcess = childProcess.spawn command, args

        apiDocProcess.on 'error', (err) ->
            console.dir err

        apiDocProcess.on 'close', (code, signal) =>
            indexPath = join outputDir, 'restapi.html'

            if fs.existsSync(indexPath)
                new RestApiPage @

            cb()

    readDir: (cb) ->
        fs.readdir @dir, (err, files) =>
            cb err if err?

            subdirs = []
            for f in files
                if f.toLowerCase() == 'manifest.coffee'
                    manifest = require(join root, @dir, f)

                    @_generateRestDocumentation =>
                        new ApiDocPage @, manifest

                        if manifest.documentation?
                            for f in manifest.documentation
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
