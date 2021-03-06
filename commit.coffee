semaphore = require 'semaphore'
async = require 'async'
{exec, spawn} = require 'child_process'
fs = require 'fs'

module.exports = class Commit
    constructor: (@baseURL, @hash) ->
        @files = []
        @fields =
            hash: @hash

    matches: (dir) ->
        dir += '/'
        for f in @files
            return true if f.substring(0, dir.length) == dir
        return false

    _fileString: (file) ->
        return "* [`#{file}`](#{@baseURL}/blob/#{@hash}/#{file})"

    toString: ->
        return """
            # #{@fields.date} #{@fields.author} [#{@fields.subject}](#{@baseURL}/commit/#{@hash})
            #{(@_fileString file for file in @files).join '\n'}
        """

logSem = semaphore(1)
commits = null

globalCommitLog = (cb) -> logSem.take ->
    done = (err) ->
        logSem.leave()
        return cb err if err?
        cb null, commits

    return done() if commits?

    baseURL = null
    commits = []
    commit = null
    gitdir = null
    err = null

    async.waterfall [
        (cb) ->
            exec "git config remote.origin.url", (err, stdout, stderr) ->
                if err?
                    console.warn 'Cannot retrieve gitlog: ' + err
                    return cb null, null, null

                cb null, stdout, stderr

        (stdout, stderr, cb) ->
            return cb null, null unless stdout?
            baseURL = stdout.toString()
                .replace /(.git)?\n+$/, ''
                .replace /^git@github.com:/, 'https://github.com/'
            cb null, baseURL

        (url, cb) ->
            return cb() unless url?
            nextline = (line) ->
                line = line.trim()
                return if line == ''

                if line[0] == '#'
                    i = line.indexOf ':'
                    header = [
                        line.substring(1, i).trim()
                        line.substring(i + 1).trim()
                    ]
                    if header[0] == ''
                        err = new Error(line)
                        cb err
                        return

                    key = header[0].toLowerCase()
                    if key == 'hash'
                        commits.push(commit = new Commit url, header[1])
                    else
                        commit.fields[key] = header[1]
                else
                    commit.files.push line

            params = [
                'log'
                '--no-merges'
                '--name-only'
                '--date=iso'
                '--pretty=#Hash:%H%n#Date:%cd%n#Author:%an%n#Subject:%s'
            ]

            gitlog = spawn 'git', params
            buff = []
            gitlog.stdout.on 'data', (data) ->
                return if err?
                last = 0
                for b, i in data
                    if b == 10
                        buff.push data.slice last, i
                        last = i + 1
                        line = Buffer.concat(buff.splice 0, buff.length).toString()
                        nextline line
                buff.push data.slice last, data.length

            errorProxy = (code) ->
                return if err?
                unless code == 0
                    err = new Error(code) unless code == 0
                    cb err
                    return

            gitlog.on 'error', (error) ->
                err = error
                cb new Error(error)

            gitlog.on 'exit', errorProxy
            gitlog.on 'close', errorProxy

            gitlog.on 'close', (code) ->
                return if err?
                nextline Buffer.concat(buff).toString()
                cb()
    ], done

module.exports.commitLog = (dir, cb) ->
    globalCommitLog (err, commits) ->
        return cb err if err?

        locals = []
        for commit in commits
            locals.push commit if commit.matches dir
        cb null, locals.join '\n\n'

