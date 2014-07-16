FS      = require 'fs'
Path    = require 'path'
mkdirp  = require 'mkdirp'
_       = require 'underscore'
hamlc   = require 'haml-coffee'
walkdir = require 'walkdir'
Mincer  = require 'mincer'
Nib     = require 'nib'
Theme   = require './_theme'

module.exports = class Theme.Templater

  sourceOf: (subject) ->
    Path.join(__dirname, '..', subject)

  constructor: (@destination) ->
    @output = {}
    Mincer.StylusEngine.configure (stylus) => stylus.use Nib()
    Mincer.CoffeeEngine.configure bare: false

    @JST = []

    templates = @sourceOf('templates')

    for template in walkdir.sync(templates)
      unless FS.lstatSync(template).isDirectory()
        relative = Path.relative(templates, template)
        dirname  = Path.dirname(relative)
        basename = Path.basename(template, '.hamlc')

        keyword = basename
        keyword = dirname + '/' + basename unless dirname == '.'
        @JST[keyword] = hamlc.compile FS.readFileSync(template, 'utf8'),
          escapeAttributes: false

  compileAsset: (from, to=false) ->
    mincer = new Mincer.Environment()
    mincer.appendPath @sourceOf('assets')

    asset = mincer.findAsset(from)
    file  = Path.join(@destination, to || from)
    dir   = Path.dirname(file)

    mkdirp.sync(dir)
    FS.writeFileSync(file, asset.buffer)

  # Render the given template with the context and the
  # global context object merged as template data. Writes
  # the content into the @output
  #
  # @param [String] template the template name
  # @param [Object] context the context object
  # @param [String] filename the output file name
  #
  render: (template, context = {}, filename = '') ->
    html = @JST[template](context)
    if filename.length > 0
        # the entity name is either a class name or a file path
        @output[context.entity.name] = html
    return html
