
fs = require 'fs'
path = require 'path'
async = require 'async'
http = require 'http'

md5 = require 'MD5'
express = require 'express'

MongoStore = require('connect-mongo')(express)

session = require('express-session')

# Sane defaults for as many initial settings as possible.
defaults =
  port: 3000
  views: []


# Apply the defaults to an app.
set_defaults = (app)->
  
  if not app.get "app_name"
    app.set "app_name", process.cwd().split("/").pop()

  if not app.get 'dir'
    app.set 'dir', process.cwd()

  view_dirs = defaults.views.push(app.get('views'))

  for k, v of defaults
    if not app.get k
      app.set k, defaults[k]



implied = module.exports = (app, options)->
  
  app ?= express()

  set_defaults(app)
  
  app.set('implied', implied)
  
  # apply the config.
  (require path.join app.get('dir'), 'config') app
  
  app.set('server', http.Server(app))
  
  process.nextTick ->
    if app.get('port')
      (app.get 'server').listen app.get("port"), ->
        console.log "Express server listening on port " + app.get("port")

  app.plugin = (plugin, opts)->

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


implied.util = require './util'

implied.mongo = require './lib/mongo'
implied.routing = require './lib/routing'
implied.boilerplate = require './lib/boilerplate'
implied.blog = require './lib/blog'
implied.users = require './lib/users'
implied.logging = require './lib/logging'
implied.admin = require './lib/admin'
implied.sendgrid = require './lib/mail/sendgrid'
