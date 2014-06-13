fs = require 'fs'

module.exports = class JSFile
    constructor: (parentDir, @srcFile) ->
        parentDir.scripts.push @

    src: (cb) ->
        fs.readFile @srcFile, 'utf-8', cb
