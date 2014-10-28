# Express Mongo Users
md5 = require 'MD5'
uuid = require 'node-uuid'
fs = require 'fs'
path = require 'path'
async = require 'async'
http = require 'http'
express = require 'express'
mongojs = require 'mongojs'
MongoStore = require('connect-mongo')(express)
#multiViews = require('multi-views')

implied = module.exports = (app, options)->
  
  options = implied.util.extend {
    serve: true # by default, serve the web app.
  }, options
  this.options = options

  app ?= express()
  # Use this when we switch to express 4.
  #multiViews.setupMultiViews(app)

  app.set('implied', implied)

  (require path.join process.cwd(), 'config') app
  
  app.set('server', http.Server(app))
  
  if options.serve
    process.nextTick ->
      (app.get 'server').listen app.get("port"), ->
        console.log "Express server listening on port " + app.get("port")

  implied.middleware =

    page: (req, res, next)->
      unless (req.method or req.originalMethod) is 'GET'
        return next()

      pagename = req.path.substring(1).replace /\/$/, ''

      fs.exists path.join(app.get('dir'), 'views', 'pages', pagename+'.jade'), (exists)->
        if exists
          res.render path.join('pages', pagename),
            req: req
        else
          next()

    # CMS
    cms: (req, res, next)->

      db = app.get 'db'

      unless (req.method or req.originalMethod) is 'GET'
        return next()

      pagename = req.path.substring(1).replace /\/$/, ''

      db.collection('cms').findOne {page: pagename}, (err, page)->
        if page
          # Override CMS.jade?
          fs.exists path.join(app.get('dir'), 'views', 'cms', pagename+'.jade'), (exists)->
            if exists
              res.render path.join('cms', pagename), page
            else
              res.render path.join('cms', 'cms.jade'), page
        else
          next()

  app.plugin = (plugin, opts)->
    
    if not this.get "app_name"
      this.set "app_name", process.cwd().split("/").pop()

    opts ?= {}

    plugin_instance = undefined # The instance to register.
    plugin_name = opts.plugin_name # The name to register under.
 
    # Initialize the plugin
    # ---------------------

    # Array of plugins
    if plugin instanceof Array
      for child in plugin
        @plugin child, opts

    else if typeof plugin is 'string'
      unless implied[plugin]
        throw "Plugin `" + plugin + "` was not found."
      app.plugin implied[plugin], implied.util.extend {plugin_name: plugin}, opts

    # A Plugin class instance
    else if plugin instanceof implied.util.Plugin
      plugin_instance = new plugin app

    # A function, simlpy call it with the app, and it can do what it pleases.
    else if typeof plugin is 'function'
      plugin app, opts
      plugin_instance = plugin
    else
      throw "Usage: app.plugin( plugin ) where plugin is of type <String> | <Function> | <Array of plugins> , but you used app.plugin(" + typeof plugin + ")"

    # Register the plugin
    # -------------------
    if plugin_instance and plugin_name # Only register if a real plugin was called.
      registered_plugins = app.get('plugins') or {}
      registered_plugins[plugin_name] = plugin_instance
      app.set 'plugins', registered_plugins
    
  app

implied.mongo = (app)->
  unless app.get 'db_name'
    app.set 'db_name', app.get 'app_name'
  connect_string = app.get 'db_name'
  if app.get 'db_password'
    connect_string = (app.get 'db_username') + ':' + (app.get 'db_password') + '@localhost/' + connect_string
  
  app.set 'db', mongojs connect_string

implied.mongo.oid_str = (inp)->
  (me.oid inp).toString()

implied.mongo.oid = (inp)->
  if inp instanceof mongojs.ObjectId
    return inp
  else if inp.bytes
    result = (implied.util.zpad(byte.toString(16),2) for byte in inp.bytes).join ''
    return mongojs.ObjectId result
  else
    return mongojs.ObjectId ''+inp

implied.boilerplate = (app)->
  
  if not app.get 'dir'
    app.set 'dir', process.cwd()

  if not app.get "upload_dir"
    app.set "upload_dir", path.join "/var", app.get "app_name"

  app.set "views", path.join app.get('dir'), "views"

  app.set "view engine", "jade"
  
  if (app.get 'env') is 'development'
    app.locals.pretty = true
    app.locals.development = true
    #app.locals.compileDebug = true
    
  #app.use express.limit '300mb'
  app.use express.bodyParser({upload_dir: '/tmp'})
  
  # Use helmet?
  if app.get('security_headers') is true
    helmet = require 'helmet'
    app.use(helmet.xframe())
    app.use(helmet.iexss())
    app.use(helmet.contentTypeOptions())
    app.use(helmet.cacheControl())
  
  app.use express.cookieParser()

  if app.get 'db_name'
    #app.use express.session secret: (app.get 'secret') or "UNSECURE-STRING", store: new MongoStore({native_parser: false})
    store_opts =
      db: app.get 'db_name'
    if app.get('db_password')
      store_opts.username = app.get 'db_username'
      store_opts.password = app.get 'db_password'

    app.use express.session
      secret: (app.get 'secret') or "UNSECURE-STRING",
      store: new MongoStore store_opts

    if app.get('csrf') is true
      app.use(express.csrf())
      app.use (req, res, next) ->
        res.locals.csrf = req.session._csrf
        next()
    
  app.use express.methodOverride()

  app.use (req, res, next)->
    if req.query.referrer
      req.session.referrer = req.query.referrer
    next()

  app.use express.static path.join app.get('dir'), 'public'
  app.use express.static app.get "upload_dir"

  app.locals.process = process

  # Middleware to make request available to templates.
  app.use (req,res,next)->
    res.locals.req = res.locals.request = req
    next()
  
  # if a cms table exists, use the cms middleware.
  #app.get('db').getCollectionNames (err, names)->
  #  if err
  #    throw err
  #  if names.indexOf('cms') > -1
  app.use implied.middleware.cms
  
  # if a pages directory exists, use the pages middleware.
  fs.exists path.join((app.get 'dir'), 'views', 'pages'), (exists)->
    if exists
      app.use implied.middleware.page
  app.use implied.middleware.cms
  app.use implied.middleware.page

  app.use app.router
  app.set('view options', { layout: false })


implied.util = require './util'
implied.blog = require './lib/blog'
implied.videos = require './lib/videos'
implied.users = require './lib/users'
implied.logging = require './lib/logging'
implied.admin = require './lib/admin'
implied.sendgrid = require './lib/mail/sendgrid'
implied.multi_views = require './lib/multi_views'


