#! /usr/bin/env coffee

###
    script converts markdown files .md into html files with the
    npm markdown module

###

markdown = require('markdown').markdown
fsUtil = require 'fs'
path = require 'path'
nopt = require 'nopt'

knownOpts = {
    "output" : String
}
shortHands = {
    "o" : ["--output"]
}

srcFilename = process.argv[2]
parsed = nopt(knownOpts, shortHands, process.argv, 2)
destFilepath = parsed.output if parsed.output?

if srcFilename?
    mdContent = fsUtil.readFileSync(srcFilename,"utf8")

    htmlContent = markdown.toHTML(mdContent.toString())

    filepath = path.dirname srcFilename

    destFilename = srcFilename.replace new RegExp("\.md$",'g'), ".html"

    fsUtil.writeFile destFilename, htmlContent, (err) ->
        if err? then console.log err else console.log "Written #{destFilename} in #{filepath}"
