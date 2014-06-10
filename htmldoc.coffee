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
        new IndexPage @

        if @parentDir?
            @parentDir.children[@name] = @
            new LogPage @
    
    index: ->
        @files['index.html']
            
    toString: ->
        @dir
    
    readDir: (cb, pageCallback) ->
        fs.readdir @dir, (err, files) =>
            cb(err) if err?
    
            for f in files
                if f.toLowerCase() == 'manifest.coffee'
                    docs = require(join root, @dir, f).documentation
                    if docs?
                        for f in docs
                            new MarkdownPage @, join(@dir, f)
                    pageCallback null, page for n, page of @files
                    cb null
                    return
                    
            fileQueue = async.queue (data, cb) ->
                    {dir, name} = data
                    file = join(dir.dir, name)
                    fs.stat file, (err, stats) ->
                        throw err if err?
                        if stats.isDirectory()
                            new Directory dir, file
                        cb()
                , 5
            
            fileQueue.drain = () ->
                cb()
    
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

            pageCallback null, page for n, page of @files

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

class AbstractPage
    constructor: (@parentDir, @url) ->
        @file = basename @url
        @parentDir.files[@file] = @
    
    src: (cb) ->
        cb new Error
        
    toString: ->
        return @url
        
    templateData: (cb) ->
        dir = @parentDir.dir
        siblings = (p for name, p of @parentDir.files)
        siblings.sort comparePages
            
        path = @path()
        navigation = ((p.treeChildren().sort comparePages) for p in path)
        
        cb null, {
            page: @
            navigation
            root: path[0]
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
        
        return (dir.index() for name, dir of @parentDir.children)
        
    path: ->
        parent = @parent()
        return [@] unless parent?
        result = parent.path()
        result.push @
        return result

class MarkdownPage extends AbstractPage
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

class IndexPage extends AbstractPage
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
    
class LogPage extends AbstractPage
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
        
writeQueue = async.queue (locals, callback) ->
        out = join('build', 'htmldoc', locals.url)
        
        async.waterfall [
            (cb) ->
                locals.src cb
            (html, cb) ->
                locals.content = html
                mkdirp dirname(out), cb
            (made, cb) ->
                if template?
                    cb null, null
                else
                    fs.readFile "#{__dirname}/htmldoc.jade", 'utf-8', cb
            (data, cb) ->
                unless template?
                    jade = require('jade')
                    template = jade.compile data
                    writeQueue.concurrency = 5
                cb null, template
            (data, cb) ->
                locals.templateData cb
            (templateData, cb) ->
                cb null, template templateData
            (page, cb) ->
                fs.writeFile out, page, cb
        ], (err) ->
            throw err if err?
            callback()
    , 1

dirQueue = async.queue (dir, cb) ->
        async.waterfall [
            (cb) ->
                dir.readDir cb, (err, pages) ->
                    cb err if err?
                    writeQueue.push pages, throwError
                    
            (cb) ->
                for name, child of dir.children
                    dirQueue.push child, throwError
                cb()
        ], cb
    , 10
    
dirQueue.push new Directory(undefined, '.'), throwError