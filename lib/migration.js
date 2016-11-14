var MIGRATION_DIR, app_dir, mm, path;

path = require('path');

app_dir = path.dirname(require.main.filename);

mm = require('mongodb-migrations');

MIGRATION_DIR = app_dir + '/migrations';

module.exports = function(app, cli) {
  var all, config, createmigration, db;
  db = app.get('db_name').split('/');
  config = {
    'host': db[0],
    'db': db[1],
    'collection': 'migrations',
    'directory': MIGRATION_DIR
  };
  createmigration = function(callback) {

    /*
     * used to dispose of migrator
     */
    var coffeeScript, done, migration_name, migrator;
    done = function(error, results) {
      return migrator.dispose(function(cb_error) {
        if (cb_error) {
          return callback(cb_error);
        } else {
          return callback(error, results);
        }
      });
    };
    if (!process.argv[4]) {
      callback(new Error('Please provide migration name'));
    }
    migrator = new mm.Migrator(config);
    migration_name = process.argv[4];
    return migrator.create(MIGRATION_DIR, migration_name, done, coffeeScript = true);
  };
  all = function(callback) {
    var migrator;
    migrator = new mm.Migrator(config);
    return migrator.runFromDir(MIGRATION_DIR, function(error, results) {
      return migrator.dispose(function(cb_error) {
        if (cb_error) {
          return callback(cb_error);
        } else {
          return callback(error, results);
        }
      });
    });
  };

  /*
   * CLI migrate command
   */
  return cli.migrate = function(callback) {
    var command, msg;
    if (!process.argv[3]) {
      msg = "\nUsage:\n" + "\tcreatemigration [name] - creates a new migration file with specified name\n" + "\tall - executes all migrations";
      callback(null, msg);
    }
    command = process.argv[3];
    switch (command) {
      case "createmigration":
        return createmigration(callback);
      case "all":
        return all(callback);
    }
  };
};
