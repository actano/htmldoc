#!/usr/bin/env coffee
fs = require 'fs'
mkdirp = require 'mkdirp'
{join, dirname} = require 'path'
async = require 'async'

throwError = (err) -> throw err if err?
template = null

Directory = require './directory'
AbstractPage = require './abstractpage'

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
            throw "#{err} in #{locals.url}" if err?
            callback()
    , 1

dirQueue = async.queue (dir, cb) ->
        dir.readDir (err, subdirs, pages) ->
            unless err?
                dir.treeChildren = ({url: "#{d.dir}/index.html", title: d.name} for d in subdirs)
                dir.treeChildren.sort AbstractPage.comparePages
                writeQueue.push pages, throwError
                dirQueue.push subdirs, throwError
            cb err
    , 100 # TODO: this is a crazy bug, occurs only for fast cpu
    # problem is that consumer is faster than producer -> queue ends too early
    
dirQueue.push new Directory(undefined, '.'), throwError