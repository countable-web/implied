# Express Mongo Users
md5 = require 'MD5'
uuid = require 'node-uuid'
fs = require 'fs'
path = require 'path'
async = require 'async'

express = require 'express'
mongolian = require 'mongolian'
MongoStore = require('express-session-mongo')


implied = module.exports = (app)->

  app ?= express()

  app.plugin = (plugin, opts)->
    
    # Array of plugins
    if plugin instanceof Array
      for child in plugin
        @plugin child, opts

    else if typeof plugin is 'string'
      unless implied[plugin]
        throw "Plugin `" + plugin "` was not found."
      app.plugin implied[plugin]

    # A Plugin class instance
    else if plugin instanceof implied.util.Plugin
      new plugin app, opts

    # A function, simlpy call it with the app, and it can do what it pleases.
    else if typeof plugin is 'function'
      plugin app, opts

    else
      throw "Usage: app.plugin( plugin ) where plugin is of type <String> | <Function> | <Array of plugins> , but you used app.plugin(" + typeof plugin + ")"

    app

implied.mongo = (app)->

  server = new mongolian()
  app.set 'db', server.db app.get 'app_name'

implied.boilerplate = (app)->
  
  if not app.get "app_name"
    app.set "app_name", "www"

  if not app.get "upload_dir"
    app.set "upload_dir", path.join "/var", app.get "app_name"

  app.set "views", path.join app.get('dir'), "views"
  app.set "view engine", "jade"
  app.use express.limit '36mb'
  app.use express.bodyParser({upload_dir: '/tmp'})
  app.use express.cookieParser()
  
  if app.get('db')
    app.use express.session secret: (app.get 'secret') or "UNSECURE-STRING", store: new MongoStore({native_parser: false})

  app.use express.methodOverride()

  app.use express.static path.join app.get('dir'), 'public'
  console.log 'upload-dir', app.get 'upload_dir'
  app.use express.static app.get "upload_dir"

  app.locals.process = process

  # Middleware to make request available to templates.
  app.use (req,res,next)->
    res.locals.req = res.locals.request = req
    next()
    
  app.use app.router
  app.set('view options', { layout: false })

implied.util = require './util'

implied.blog = require './lib/blog'
implied.videos = require './lib/videos'
implied.users = require './lib/users'
implied.logging = require './lib/logging'
implied.admin = require './lib/admin'

implied.common = require './lib/common'


