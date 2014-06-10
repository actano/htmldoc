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
                            new MarkdownPage @, join(@dir, f)
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
        siblings = (p for name, p of @parentDir.files)
        siblings.sort comparePages
            
        cb null, {
            page: @
            navigation
            root: path[0]
            siblings
            title
            
            inpath: (p) ->
                for x in path
                    return true if p.url == x.url
                return false
                
            relative: (url) ->
                relative dir, url
                
            }
        
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
                    template = jade.compile data
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