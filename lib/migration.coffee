path = require('path')
app_dir = path.dirname(require.main.filename)
mm = require('mongodb-migrations')

MIGRATION_DIR = app_dir + '/migrations'

module.exports = (app, cli)->
  db = app.get('db_name').split('/')
  config = {
    'host': db[0]
    'db': db[1]
    'collection': 'migrations'
    'directory': MIGRATION_DIR
  }

  createmigration = (callback) ->

    # used to dispose of migrator
    done = (error, results) ->
      migrator.dispose (cb_error) ->
        if cb_error
          callback(cb_error)
        else
          callback(error, results)


    unless process.argv[4]
      callback(new Error('Please provide migration name'))

    migrator = new mm.Migrator config
    migration_name = process.argv[4]

    migrator.create MIGRATION_DIR, migration_name, done, coffeeScript=true


  all = (callback) ->
    migrator = new mm.Migrator config

    migrator.runFromDir MIGRATION_DIR, (error, results) ->
      migrator.dispose (cb_error) ->
        if cb_error
          callback(cb_error)
        else
          callback(error, results)


  # CLI migrate command
  cli.migrate = (callback) ->
    unless process.argv[3]
      msg = "\nUsage:\n" +
            "\tcreatemigration [name] - creates a new migration file with specified name\n" +
            "\tall - executes all migrations"

      callback(null, msg)

    command = process.argv[3]
    switch command
      when "createmigration" then createmigration(callback)
      when "all" then all(callback)
