#!/usr/bin/env coffee
fs = require 'fs'
mkdirp = require 'mkdirp'
{markdown} = require 'markdown'
{basename, dirname, join, normalize, relative} = require 'path'
async = require 'async'
template = null

tree = {}
base = process.cwd()
root = relative __dirname, base

addFile = (file) ->
    file = normalize file
    dir = relative base, dirname(file)

    entry = {
        url: file
        src: (cb) ->
            async.waterfall [
                (cb) ->
                    fs.readFile file, 'utf-8', cb
                (content, cb) ->
                    cb null, markdown.toHTML content
            ], cb
    }

    url = null
    b = basename(file).toLowerCase()
    if b.substr(-3) == '.md'
        entry.title = basename(file).substring(0, b.length - 3)
        url = "#{b.substring(0, b.length - 3)}.html"
        url = 'index.html' if b == 'readme.md'
        entry.url = join dirname(file), url

    tree[dir] = {} unless tree[dir]?
    tree[dir][basename entry.url] = entry


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
                addFile join(dir, f)
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
            addFile join(dir, f)

locateFiles = (cb) ->
    console.log "Locating files"
    readDir '.', cb


fixDir = (dir) ->
    unless dir == '.'
        fixDir dirname(dir)

    dir = '' if dir == '.'
    tree[dir] = {} unless tree[dir]?
    d = tree[dir]
    unless d['index.html']
        d['index.html'] = {
            title: 'Index'
            url: join dir, 'index.html'
            src: (cb) ->
                items = []
                for url, page of d
                    if page.title?
                        items.push "* [#{page.title}](#{url})"
                html = markdown.toHTML(items.join('\n'))
                cb null, html
        }


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
            cb null, template page
    ], cb
renderQueue = async.queue render, 1

writeFile = (locals, callback) ->
    async.waterfall [
        locals.src
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
    for dir, files of tree
        fixDir dir

    for dir, files of tree
        for file, locals of files
            locals.out = join('build', 'htmldoc', dir, file)
            writeQueue.push locals, (err) ->
                throw err if err?
