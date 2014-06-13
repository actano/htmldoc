#!/usr/bin/env coffee
fs = require 'fs'
semaphore = require 'semaphore'
mkdirp = require 'mkdirp'
marked = require 'marked'
{basename, dirname, join, normalize, relative} = require 'path'
{exec, spawn} = require 'child_process'
async = require 'async'
util = require 'util'
template = null
title = 'RPLAN - Developer Documentation'

base = process.cwd()
root = relative __dirname, base

throwError = (err) ->
    throw err if err?

template = null

class Directory
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

class AbstractPage
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

class JSFile
    constructor: (parentDir, @srcFile) ->
        parentDir.scripts.push @
        
    src: (cb) ->
        fs.readFile @srcFile, 'utf-8', cb
        
class MarkdownPage extends AbstractPage
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

class IndexPage extends AbstractPage
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

class Commit
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

commitLog = (dir, cb) ->
    globalCommitLog (err, commits) ->
        return cb err if err?
        
        locals = []
        for commit in commits
            locals.push commit if commit.matches dir
        cb null, locals.join '\n'

class LogPage extends AbstractPage
    constructor: (parentDir) ->
        super parentDir, join parentDir.dir, 'commit.html'
        @title = 'Commits'
    
    src: (cb) ->
        commitLog @parentDir.dir, (err, content) ->
            if err?
                cb err
                return
                
            cb null, marked content
                    
writeQueue = async.queue (locals, callback) ->
        locals.out = join('build', 'htmldoc', locals.url)
        
        async.waterfall [
            (cb) ->
                if template?
                    cb null, null
                else
                    fs.readFile "#{__dirname}/htmldoc.jade", 'utf-8', cb
            (data, cb) ->
                unless template?
                    jade = require('jade')
                    template = jade.compile data,
                        filename: "#{__dirname}/htmldoc.jade"
                    writeQueue.concurrency = 10
                cb null            
            (cb) ->
                path = locals.path()
                navigation = (p.parentDir.treeChildren for p in path)
                locals.templateData path, navigation, cb
            (templateData, cb) ->
                locals.src (err, html) ->
                    templateData.content = html
                    cb err, templateData                    
            (templateData, cb) ->
                mkdirp dirname(locals.out), (err) ->
                    cb err, templateData
            (templateData, cb) ->
                fs.writeFile locals.out, (template templateData), cb
        ], (err) ->
            throw err if err?
            callback()
    , 1

dirQueue = async.queue (dir, cb) ->
        dir.readDir (err, subdirs, pages) ->
            unless err?
                dir.treeChildren = ({url: "#{d.dir}/index.html", title: d.name} for d in subdirs)
                dir.treeChildren.sort comparePages
                writeQueue.push pages, throwError
                dirQueue.push subdirs, throwError
            cb err
    , 10
    
dirQueue.push new Directory(undefined, '.'), throwError