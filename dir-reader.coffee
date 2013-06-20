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
            exec "rm -r #{htmlDir}/*", (err,stdout,stderr) ->
                console.log err if err?

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
        #console.log filepath
        if filepath.match(new RegExp(includes, 'g'))
            console.log filepath
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

            exec "cp #{sourceFile} #{targetDir}", (err, stdout)  ->
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

    #sidebarTemplate = jade.compile fs.readFileSync './views/index.jade', 'utf8'
    #html = sidebarTemplate paths
    linkList = createLinkList paths

    htmlContent = """
                  <html>
                    <head>
                        <style>.sidebar {width:300px;height:600px;border: 0px;float:left;} .list {list-style-type: none;} .main {width:900px;height:600px;border: 0px;float:left;}</style>
                    </head>
                    <body><div class="sidebar">
                  """
    htmlContent += linkList
    htmlContent +="""
                        </div>
                        <iframe name="main" class="main" src="Readme.html"></iframe>
                    </body>
                  </html>
                   """

    fs.writeFile "#{root}/#{docFolder}/index.html", htmlContent, (err) ->
        if err? then console.error err
        console.log 'Written index.html'
        callback()


createLinkList = (paths) ->
    linkList = '<ul class="list">'
    for i in paths
        linkList += '<li><a target="main" href="' + i + '">' + i + '</a></li>'
    linkList += '</ul>'
