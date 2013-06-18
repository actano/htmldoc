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

includes = '.*.html$'
excludes = 'build|test'
#excludes = 'chef\/cookbooks|node_modules|htmldoc|build'

docFolder = "htmldoc"



# get root directory
getProjectRoot = (callback) ->
    exec 'npm bin', (err, stdout)  ->
        if err?
            console.log err
        root = path.resolve stdout, "../../"
        callback root

# create html directory and start processing
getProjectRoot (root) ->

    htmlDir = "#{root}/#{docFolder}"
    filepaths = []

    rootFile = "#{root}/Readme.md"

    mdContent = fs.readFileSync(rootFile,"utf8")
    htmlContent = markdown.toHTML(mdContent.toString())
    fs.writeFile "#{root}/Readme.html", htmlContent, (err) ->
        if err? then console.log err else console.log "Written #{rootFile} in #{root}"

    # add file in root path
    filepaths.push 'Readme.html'

    fs.exists htmlDir, (exists) ->
        if exists
            removeDir.removeSync htmlDir

        mkdirp htmlDir, (err) ->
            if err?
                console.log err

            async.series [
                (callback) ->
                    scanForHtmlFiles filepaths, root, callback
            ,
                (callback) ->
                    copyHtmlFiles filepaths, root, htmlDir, callback
            ,
                (callback) ->
                    createIndexFile root, filepaths, callback
            ]


scanForHtmlFiles = (filepaths, root, callback) ->

    dive "#{root}/lib", { all: false }, (err, filepath) ->
        if err? then console.error err

        if filepath.match(new RegExp(includes, 'g'))
            if excludes?
                if not filepath.match(new RegExp(excludes, 'g'))
                    relFilepath = path.relative root, filepath
                    filepaths.push relFilepath
            else
                relFilepath = path.relative root, filepath
                filepaths.push relFilepath
    , () ->
        console.log 'scanning complete'
        callback()


copyHtmlFiles = (filepaths, root, htmlDir, callback) ->

    async.each filepaths, (filepath, callback) ->
        relDirname = path.dirname filepath

        sourceFile = "#{root}/#{filepath}"
        targetDir = "#{htmlDir}/#{relDirname}"

        console.log targetDir

        # root Readme.html
        if relDirname isnt ''
            targetDir += "/"

        # copy the html file to collection directory
        mkdirp targetDir, (err) ->
            if err?
                console.log err

            exec "mv #{sourceFile} #{targetDir}", (err, stdout)  ->
                if err?
                    console.log err
                filename = path.basename filepath
                console.log "File moved: #{targetDir}#{filename}"

                callback()
    , (err) ->
        if err?
            console.log err
        console.log 'copying complete'

        callback()

createIndexFile = (root, paths, callback) ->

    sidebarTemplate = jade.compile fs.readFileSync 'index.jade', 'utf8'

    html = sidebarTemplate paths

    htmlContent = """
                  <html>
                    <head>
                        <style>.sidebar {width:300px;height:800px;border: 0px;} .main {width:900px;height:800px;border: 0px;}</style>
                    </head>
                    <body><div class="sidebar"></div>
                  """
    htmlContent += linkList
    htmlContent +="""
                        </div>
                        <iframe name="main" class="main" src="Readme.html"></iframe>
                    </body>
                  </html>
                   """

    fs.writeFile "#{root}/#{docFolder}/sidebar.html", htmlContent, (err) ->
        if err? then console.error err
        console.log 'Written index.html'
        callback()

###
createLinkList = (paths) ->
    linkList = '<ul>'
    for i in paths
        linkList += '<li><a target="main" href="' + i + '">' + i + '</a></li>'
    linkList += '</ul>'
###