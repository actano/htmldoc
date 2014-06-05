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

class Entry
    constructor: (file) ->
        @url = normalize file
        @dir = relative base, dirname(file)
        @dir = '.' if @dir == ''
        @file = basename @url
        if @dir == ''
            throw file
        tree[@dir] = {} unless tree[@dir]?
        tree[@dir][@file] = @
    
    src: (cb) ->
        cb new Error
        
    toString: ->
        return @url
        
    parent: ->
        unless @file == 'index.html'
            return tree[@dir]['index.html']
        
        return null if @dir == '.'

        parent = dirname @dir
        return tree[parent]['index.html']
            
    children: ->
        return @treeChildren().concat(@dirChildren())
        
    dirChildren: ->
        return [] unless @file == 'index.html'
        
        result = []
        for name, file of tree[@dir]
            unless name == 'index.html'
                result.push file
        return result
        
    treeChildren: ->
        return [] unless @file == 'index.html'
        
        result = []

        for dir, files of tree
            if dir != '.' && dirname(dir) == @dir
                result.push files['index.html']
        return result
        
    siblings: ->
        parent = @parent()
        return unless parent? then [@] else parent.children()
    
    path: ->
        parent = @parent()
        return [@] unless parent?
        result = parent.path()
        result.push @
        return result

class FileEntry extends Entry
    constructor: (@srcFile) ->
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

        super url

    src: (cb) ->
        srcFile = @srcFile
        async.waterfall [
            (cb) =>
                fs.readFile srcFile, 'utf-8', cb
            (content, cb) ->
                cb null, markdown.toHTML content
        ], cb

class IndexEntry extends Entry
    constructor: (dir) ->
        super join dir, 'index.html'
        @title = basename dir
        
    src: (cb) ->
        items = []
        for url, page of tree[@dir]
            if page.title?
                items.push "* [#{page.title}](#{url})"
        html = markdown.toHTML(items.join('\n'))
        cb null, html
    
class LogEntry extends Entry
    constructor: (dir) ->
        super join dir, 'commit.html'
        @title = 'Commits'
    
    src: (cb) ->
        dir = @dir
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
        
readDir = (dir, cb) ->
    fs.readdir dir, (err, files) ->
        throw err if err?

        if scanManifest dir, files
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
                    readDir file, callback
                    return
                callback()

        for f in files
            if f.substring(0, 1) == '.'
                continue

            name = f.toLowerCase()
            if name == 'build' or name == 'node_modules'
                continue

            if name.substr(-3) == ".md"
                new FileEntry join(dir, f)
                continue

            countdown++

            stat join(dir, f)

        callback()

scanManifest = (dir, files) ->
    for f in files
        if f.toLowerCase() == 'manifest.coffee'
            readManifest dir, f
            return true
    return false

readManifest = (dir, f) ->
    docs = require(join root, dir, f).documentation
    if docs?
        for f in docs
            new FileEntry join(dir, f)

locateFiles = (cb) ->
    readDir '.', cb

fixDir = (dir) ->
    unless dir == '.'
        fixDir dirname(dir)

    tree[dir] = {} unless tree[dir]?
    d = tree[dir]
    unless d['commit.html'] || dir == '.'
        new LogEntry dir

    unless d['index.html']
        new IndexEntry dir    

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
    ], cb

render = (page, cb) ->
    jade = require('jade') unless jade?
    async.waterfall [
        loadTemplate
        (template, cb) ->
            cb null, template {
                page, 
                path: page.path(), 
                root: tree['.']['index.html'],
                title,
                
                inpath: (path, p) ->
                    return path.indexOf(p) >= 0
                    
                relative: (p) ->
                    relative page.dir, p.url
                }
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

locateFiles ->
    for dir of tree
        fixDir dir        

    for dir, files of tree
        for file, locals of files
            locals.out = join('build', 'htmldoc', dir, file)
            writeQueue.push locals, (err) ->
                throw err if err?