var MongoStore, async, defaults, express, fs, http, implied, md5, path, session, set_defaults;

fs = require('fs');

path = require('path');

async = require('async');

http = require('http');

md5 = require('MD5');

express = require('express');

MongoStore = require('connect-mongo')(express);

session = require('express-session');


/*
 * Sane defaults for as many initial settings as possible.
 */

defaults = {
  port: 3000,
  listen: true,
  views: []
};


/*
 * Apply the defaults to an app.
 */

set_defaults = function(app) {
  var k, results, v, view_dirs;
  if (!app.get("app_name")) {
    app.set("app_name", process.cwd().split("/").pop());
  }
  if (!app.get('dir')) {
    app.set('dir', process.cwd());
  }
  view_dirs = defaults.views.push(app.get('views'));
  results = [];
  for (k in defaults) {
    v = defaults[k];
    if (!app.get(k)) {
      results.push(app.set(k, defaults[k]));
    } else {
      results.push(void 0);
    }
  }
  return results;
};

implied = module.exports = function(app, options) {
  if (app == null) {
    app = express();
  }
  set_defaults(app);
  app.set('implied', implied);

  /*
   * apply the config.
   */
  var config_filename = process.env.CONFIG_FILENAME || 'config';
  console.log('cff', config_filename);
  (require(path.join(app.get('dir'), config_filename)))(app);
  
  // raven request handler must be first to capture stuff properly.
  if (app.get('sentry_url')) {
    var raven = require('raven');
    app.set('raven', raven);
    raven.config(app.get('sentry_url')).install();
    app.use(raven.requestHandler());
  }

  app.set('server', http.Server(app));

  process.nextTick(function() {
    if (app.get('port') && options.listen) {
      return (app.get('server')).listen(app.get("port"), function() {
        console.log("Express server listening on port " + app.get("port"));
        return console.log("Server running in the " + (app.get("env")) + " environment");
      });
    }
  });
  
  app.plugin = function(plugin, opts) {
    var child, i, len, plugin_instance, plugin_name, registered_plugins;
    if (opts == null) {
      opts = {};
    }
    plugin_instance = void 0;
    plugin_name = opts.plugin_name;

    /*
     * Initialize the plugin
     * ---------------------
     * Array of plugins
     */
    if (plugin instanceof Array) {
      for (i = 0, len = plugin.length; i < len; i++) {
        child = plugin[i];
        this.plugin(child, opts);
      }
    } else if (typeof plugin === 'string') {
      if (!implied[plugin]) {
        throw "Plugin `" + plugin + "` was not found.";
      }
      app.plugin(implied[plugin], implied.util.extend({
        plugin_name: plugin
      }, opts));

      /*
       * A Plugin class instance
       */
    } else if (plugin instanceof implied.util.Plugin) {
      plugin_instance = new plugin(app);

      /*
       * A function, simlpy call it with the app, and it can do what it pleases.
       */
    } else if (typeof plugin === 'function') {
      plugin(app, opts);
      plugin_instance = plugin;
    } else {
      throw "Usage: app.plugin( plugin ) where plugin is of type <String> | <Function> | <Array of plugins> , but you used app.plugin(" + typeof plugin + ")";
    }

    /*
     * Register the plugin
     * -------------------
     */
    if (plugin_instance && plugin_name) {
      registered_plugins = app.get('plugins') || {};
      registered_plugins[plugin_name] = plugin_instance;
      return app.set('plugins', registered_plugins);
    }
  };
  return app;
};

implied.util = require('./util');

implied.mongo = require('./lib/mongo');

implied.routing = require('./lib/routing');

implied.boilerplate = require('./lib/boilerplate');

implied.blog = require('./lib/blog');

implied.users = require('./lib/users');

implied.logging = require('./lib/logging');

implied.admin = require('./lib/admin');

implied.sendgrid = require('./lib/mail/sendgrid');

implied.cli = require('./lib/cli');
