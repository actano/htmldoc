semaphore = require 'semaphore'
async = require 'async'
{exec, spawn} = require 'child_process'

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

    async.waterfall [
        (cb) ->
            exec 'git config remote.origin.url', cb

        (stdout, stderr, cb) ->
            baseURL = stdout.toString()
                .replace /(.git)?\n+$/, ''
                .replace /^git@github.com:/, 'https://github.com/'
            cb null, baseURL

        (url, cb) ->
            nextline = (line) ->
                line = line.trim()
                return if line == ''

                if line[0] == '#'
                    i = line.indexOf ':'
                    header = [
                        line.substring(1, i).trim()
                        line.substring(i + 1).trim()
                    ]
                    throw line if header[0] == ''
                    key = header[0].toLowerCase()
                    if key == 'hash'
                        commits.push(commit = new Commit url, header[1])
                    else
                        commit.fields[key] = header[1]
                else
                    commit.files.push line

            gitlog = spawn 'git', [
                'log'
                '--no-merges'
                '--name-only'
                '--date=iso'
                "--pretty=#Hash:%H%n#Date:%cd%n#Author:%an%n#Subject:%s"
            ]
            buff = []
            gitlog.stdout.on 'data', (data) ->
                last = 0
                for b, i in data
                    if b == 10
                        buff.push data.slice last, i
                        last = i + 1
                        line = Buffer.concat(buff.splice 0, buff.length).toString()
                        nextline line
                buff.push data.slice last, data.length

            gitlog.on 'close', (code) ->
                return cb new Error(code) unless code == 0
                nextline Buffer.concat(buff).toString()
                cb()
    ], done

module.exports.commitLog = (dir, cb) ->
    globalCommitLog (err, commits) ->
        return cb err if err?

        locals = []
        for commit in commits
            locals.push commit if commit.matches dir
        cb null, locals.join '\n'

