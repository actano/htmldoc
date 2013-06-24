#! /usr/bin/env coffee


###
    script dives into root/lib and collects the filepaths of all htmls except in those
    folders mentioned in excludes variable, then all files will be copied with relative
    hierachy into docFolder, a sidebar.html and a index.html is created and put
    in the root of docFolder

###



fs = require 'fs'
dive = require 'dive'
path = require 'path'
{exec} = require 'child_process'
mkdirp = require 'mkdirp'
removeDir = require 'remove'
async = require 'async'
markdown = require('markdown').markdown
jade = require 'jade'


#excludes = 'chef\/cookbooks|node_modules|htmldoc|build'

enviroment =
    rootPath: ''
    rootDocNamePattern: 'readme.md'
    docPath: 'htmldoc'
    rootDocFilename: ''
    includes: '.*.html$'
    excludes: 'build|test'
    foundFiles: []

# get root directory
getProjectRoot = (env, cb) ->
    exec 'npm bin', (err, stdout)  ->
        if err?
            console.log err
        env.rootPath = path.resolve stdout, "../../"
        cb()

getRootDocFile = (env, cb) ->
    fs.readdir env.rootPath, (err,files) ->
        for file in files
            if file.match new RegExp("readme.md", 'i') then env.rootDocFilename = file
        cb()

convertRootDocFile = (env, cb) ->
    fs.readFile "#{env.rootPath}/#{env.rootDocFilename}", "utf8", (err,fileContent) ->

        htmlContent = markdown.toHTML(fileContent.toString())
        destFilename = path.basename env.rootDocFilename, '.md'
        fs.writeFile "#{env.rootPath}/#{destFilename}.html", htmlContent, (err) ->
            if err? then console.log err

        env.foundFiles.push "#{destFilename}.html"

        cb()

checkDocFolder = (env, cb) ->
    fs.exists "#{env.rootPath}/#{env.docPath}", (exists) ->
        if exists
            exec "rm -r #{env.rootPath}/#{env.docPath}/*", (err,stdout,stderr) ->
                console.log err if err?
                cb()
        else
            mkdirp "#{env.rootPath}/#{env.docPath}", (err) ->
                console.log err if err?
                cb()

scanForHtmlFiles = (env, cb) ->

    dive "#{env.rootPath}/lib", { all: false }, (err, filepath) ->
        if err? then console.error err
        #console.log filepath
        if filepath.match(new RegExp(env.includes, 'g'))
            if not filepath.match(new RegExp(env.excludes, 'g'))
                env.foundFiles.push path.relative env.rootPath, filepath
    , () ->
        cb()


copyHtmlFiles = (env, cb) ->

    async.each env.foundFiles, (filepath, callback) ->
        relDirname = path.dirname filepath

        sourceFile = "#{env.rootPath}/#{filepath}"
        targetDir = "#{env.rootPath}/#{env.docPath}/#{relDirname}"

        console.log targetDir

        # root Readme.html
        if relDirname isnt ''
            targetDir += "/"

        # copy the html file to collection directory
        mkdirp targetDir, (err) ->
            if err?
                console.log err

            exec "cp #{sourceFile} #{targetDir}", (err, stdout)  ->
                if err?
                    console.log err
                filename = path.basename filepath
                console.log "File moved: #{targetDir}#{filename}"

                cb()
    , (err) ->
        if err?
            console.log err
        console.log 'copying complete'

        cb()

createIndexFileFromJade = (env, cb) ->

    sidebarTemplate = jade.compile fs.readFileSync './views/index.jade', 'utf8'

    links =
        paths: env.foundFiles

    htmlContent = sidebarTemplate links

    fs.writeFile "#{env.rootPath}/#{env.docPath}/index.html", htmlContent, (err) ->
        if err? then console.error err
        console.log 'Written index.html'
        cb()

main = ->
    async.series [
        (cb) ->
            getProjectRoot enviroment, cb
    ,
        (cb) ->
            getRootDocFile enviroment, cb
    ,
        (cb) ->
            convertRootDocFile enviroment, cb
    ,
        (cb) ->
            checkDocFolder enviroment, cb
    ,
        (cb) ->
            scanForHtmlFiles enviroment, cb
    ,
        (cb) ->
            copyHtmlFiles enviroment, cb
    ,
        (cb) ->
            createIndexFileFromJade enviroment, cb

    ]


main()





