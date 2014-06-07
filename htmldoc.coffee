#!/usr/bin/env coffee
fs = require 'fs'
mkdirp = require 'mkdirp'
{markdown} = require 'markdown'
{basename, dirname, join, normalize, relative} = require 'path'
{exec, spawn} = require 'child_process'
async = require 'async'
util = require 'util'
template = null
title = 'RPLAN - Developer Documentation'

tree = {}
base = process.cwd()
root = relative __dirname, base

class Directory
    constructor: (@dir) ->
        @name = basename @dir    
        @files = {}
        @children = {}
        tree[@dir] = @
        new IndexEntry @

        unless @dir == '.'
            @parentDir = getDir dirname @dir
            @parentDir.children[@name] = @
            new LogEntry @
    
    index: ->
        @files['index.html']
            
    toString: ->
        @dir

    scanManifest: (files) ->
        for f in files
            if f.toLowerCase() == 'manifest.coffee'
                @readManifest f
                return true
        return false
    
    readManifest: (f) ->
        docs = require(join root, @dir, f).documentation
        if docs?
            for f in docs
                new FileEntry @, join(@dir, f)

    readDir: (cb) ->
        _dir = @
        fs.readdir @dir, (err, files) ->
            throw err if err?
    
            if _dir.scanManifest files
                cb()
                return
    
            countdown = 1
            callback = ->
                countdown--
                if countdown == 0
                    cb()
    
            stat = (file) ->
                fs.stat file, (err, stats) ->
                    throw err if err?
                    if stats.isDirectory()
                        getDir(file).readDir callback
                        return
                    callback()
    
            for f in files
                if f.substring(0, 1) == '.'
                    continue
    
                name = f.toLowerCase()
                if name == 'build' or name == 'node_modules'
                    continue
    
                if name.substr(-3) == ".md"
                    new FileEntry _dir, join(_dir.dir, f)
                    continue
    
                countdown++
    
                stat join(_dir.dir, f)
    
            callback()
                
getDir = (dir) ->
    return tree[dir] if tree[dir]?
    return new Directory(dir)
    
# Order: Indexfiles, Title (locale), Filename

comparePages = (a,b) ->
    aindex = a.parentDir.index() == a
    bindex = b.parentDir.index() == b
    return -1 if aindex && !bindex
    return 1 if bindex && !aindex
    if a.title? && b.title?
        result = a.title.localeCompare b.title
        return result unless result == 0
    else
        return -1 if !b.title?
        return 1 if !a.title?
        
    return a.file.localeCompare b.file

class Entry
    constructor: (@parentDir, @url) ->
        @file = basename @url
        @parentDir.files[@file] = @
    
    src: (cb) ->
        cb new Error
        
    toString: ->
        return @url
        
    templateData: ->
        dir = @parentDir.dir
        siblings = (p for name, p of @parentDir.files)
        siblings.sort comparePages
            
        path = @path()
        navigation = ((p.treeChildren().sort comparePages) for p in path)
        
        return {
            page: @
            navigation
            root: tree['.'].index()
            siblings
            title
            
            inpath: (p) ->
                return path.indexOf(p) >= 0
                
            relative: (p) ->
                relative dir, p.url
                
            }
        
    parent: ->        
        unless @file == 'index.html'
            return @parentDir.index()
        
        return null unless @parentDir.parentDir
        return @parentDir.parentDir.index()
            
    treeChildren: ->        
        return [] unless @ == @parentDir.index()
        
        result = []

        for name, dir of @parentDir.children
            result.push dir.index()
        return result
        
    path: ->
        parent = @parent()
        return [@] unless parent?
        result = parent.path()
        result.push @
        return result

class FileEntry extends Entry
    constructor: (parentDir, @srcFile) ->
        url = @srcFile
        file = basename url
        b = file.toLowerCase()
        if b.substr(-3) == '.md'
            if b == 'readme.md'
                @title = basename dirname url
                file = 'index.html'                
            else
                @title = file.substring(0, b.length - 3)
                file = "#{@title}.html"
            url = join dirname(url), file

        super parentDir, url

    src: (cb) ->
        srcFile = @srcFile
        async.waterfall [
            (cb) =>
                fs.readFile srcFile, 'utf-8', cb
            (content, cb) ->
                cb null, markdown.toHTML content
        ], cb

class IndexEntry extends Entry
    constructor: (parentDir) ->
        super parentDir, join parentDir.dir, 'index.html'
        @title = basename parentDir.name
        
    src: (cb) ->
        items = []
        for url, page of @parentDir.files
            if page.title?
                items.push "* [#{page.title}](#{url})"
        html = markdown.toHTML(items.join('\n'))
        cb null, html
    
class LogEntry extends Entry
    constructor: (parentDir) ->
        super parentDir, join parentDir.dir, 'commit.html'
        @title = 'Commits'
    
    src: (cb) ->
        dir = @parentDir.dir
        async.waterfall [
            (cb) ->
                exec 'git config remote.origin.url', cb
            (stdout, stderr, cb) ->
                url = stdout.toString()
                    .replace /(.git)?\n+$/, ''
                    .replace /^git@github.com:/, 'https://github.com/'
                cb null, url
            (url, cb) ->
                lines = []
                nextline = (line) ->
                    return if line == ''
                    line = "    #{line}" unless line[0] == '#'
                    lines.push line
                    
                gitlog = spawn 'git', [
                    'log'
                    '--no-merges'
                    '--name-only'
                    '--date=iso'
                    "--pretty=# %cd %an [%s](#{url}/commit/%H)"
                    '--'
                    dir
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
                    cb new Error(code) unless code == 0
                    nextline Buffer.concat(buff).toString()
                    cb null, lines.join '\n'
                                            
            (stdout, cb) ->
                cb null, markdown.toHTML stdout
        ], cb
        
loadTemplate = (cb) ->
    async.waterfall [
        (cb) ->
            fs.readFile "#{__dirname}/htmldoc.jade", 'utf-8', cb
        (data, cb) ->
            jade = require('jade') unless jade?
            template = jade.compile data
            loadTemplate = (cb) ->
                cb null, template
            loadTemplate cb
            renderQueue.worker = 5
    ], cb

render = (page, cb) ->
    jade = require('jade') unless jade?
    async.waterfall [
        loadTemplate
        (template, cb) ->
            cb null, template page.templateData()
    ], cb
renderQueue = async.queue render, 1

writeFile = (locals, callback) ->
    async.waterfall [
        (cb) ->
            locals.src cb
        (html, cb) ->
            locals.content = html
            mkdirp dirname(locals.out), cb
        (made, cb) ->
            render locals, cb
        (page, cb) ->
            fs.writeFile locals.out, page, (err) -> cb err
    ], callback

writeQueue = async.queue writeFile, 10

new Directory('.').readDir ->
    for dir, d of tree
        for file, locals of d.files
            locals.out = join('build', 'htmldoc', dir, file)
            writeQueue.push locals, (err) ->
                throw err if err?