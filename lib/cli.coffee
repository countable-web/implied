migration = require './migration'

cli = module.exports = (app)->
  migration app, cli
  app.set('cli', cli)
