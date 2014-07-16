strftime    = require 'strftime'
FS          = require 'fs'
Path        = require 'path'
Templater   = require './templater'
TreeBuilder = require './tree_builder'

Theme = require './_theme'
Codo  = require 'codo'

module.exports = class Theme.Theme

  options: [
    {name: 'private', alias: 'p', describe: 'Show privates', boolean: true, default: false}
    {name: 'analytics', alias: 'a', describe: 'The Google analytics ID', default: false}
    {name: 'title', alias: 't', describe: 'HTML Title', default: 'CoffeeScript API Documentation'}
  ]

  @compile: (environment) ->
    theme = new @(environment)
    theme.compile()

  constructor: (@environment) ->
    @templater  = new Templater(@environment.options.output)
    @referencer = new Codo.Tools.Referencer(@environment)

  compile: ->
    @renderClasses()
    @renderMixins()
    @renderFiles()

  getOutput: ->
    return @templater.output

  #
  # HELPERS
  #
  awareOf: (needle) ->
    @environment.references[needle]?

  reference: (needle, prefix) ->
    @pathFor(@environment.reference(needle), undefined, prefix)

  anchorFor: (entity) ->
    if entity instanceof Codo.Meta.Method
      "#{entity.name}-#{entity.kind}"
    else if entity instanceof Codo.Entities.Property
      "#{entity.name}-property"
    else if entity instanceof Codo.Entities.Variable
      "#{entity.name}-variable"

  pathFor: (kind, entity, prefix='') ->
    unless entity?
      entity = kind
      kind = 'class'  if entity instanceof Codo.Entities.Class
      kind = 'mixin'  if entity instanceof Codo.Entities.Mixin
      kind = 'file'   if entity instanceof Codo.Entities.File
      kind = 'extra'  if entity instanceof Codo.Entities.Extra
      kind = 'method' if entity.entity instanceof Codo.Meta.Method
      kind = 'variable' if entity.entity instanceof Codo.Entities.Variable
      kind = 'property' if entity.entity instanceof Codo.Entities.Property

    switch kind
      when 'file', 'extra'
        prefix + kind + '/' + entity.name + '.html'
      when 'class', 'mixin'
        prefix + kind + '/' + entity.name.replace(/\./, '/') + '.html'
      when 'method', 'variable'
        @pathFor(entity.owner, undefined, prefix) + '#' + @anchorFor(entity.entity)
      else
        entity

  activate: (text, prefix, limit=false) ->
    text = @referencer.resolve text, (link, label) =>
      "<a href='#{@pathFor link, undefined, prefix}'>#{label}</a>"

    Codo.Tools.Markdown.convert(text, limit)


  calculatePath: (filename) ->
    dirname = Path.dirname(filename)
    dirname.split('/').map(-> '..').join('/')+'/' unless dirname == '.'

  render: (source, destination, context={}) ->
    globalContext =
      environment: @environment
      path:        @calculatePath(destination)
      strftime:    strftime
      anchorFor:   @anchorFor
      pathFor:     @pathFor
      reference:   @reference
      awareOf:     @awareOf
      activate:    => @activate(arguments...)
      render:      (template, context={}) =>
        context[key] = value for key, value of globalContext
        @templater.render template, context

    context[key] = value for key, value of globalContext
    @templater.render source, context, destination

  #
  # RENDERERS
  #

  renderClasses: ->
    for klass in @environment.allClasses()
      @render 'class', @pathFor('class', klass),
        entity: klass

  renderMixins: ->
    for mixin in @environment.allMixins()
      @render 'mixin', @pathFor('mixin', mixin),
        entity: mixin

  renderFiles: ->
    
    for file in @environment.allFiles()
      @render 'file', @pathFor('file', file),
        entity: file