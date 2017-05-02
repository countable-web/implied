var express,
  hasProp = {}.hasOwnProperty;

express = require('express');

var raven;

/*
 * Implied logging module.
 *
 */

module.exports = function(app) {
  
  var mailer, prod_error;
  
  mailer = app.get('mailer');
  
  if (process.env.NODE_ENV === "development") {
    app.use(express.errorHandler({
      dumpExceptions: true,
      showStack: true
    }));
  }
  
  app.set('view options', {
    layout: false

    /*
     * prod_error - handle an error on a production site.
     * @param opts.title {string}
     * @param opts.message {string}
     * @param callback (err)->
     */
  });
  
  app.get('/fail', function(req,res){
    console.log('This is a test console.log message');
    console.warn('This is a test console.warn message');
    console.error('This is a test console.error message');
    app.capture('it broke!!!');
    throw new Error('This is a test 500 error, NODE_ENV='+process.env.NODE_ENV+'!')
  });

  app.capture = function(message, opts) {
    if (app.get('raven')) {
      app.get('raven').captureMessage(message || '(no message)', opts || {});
    }
  }

  prod_error = function(opts, callback) {
    return mailer.send_mail({
      subject: "ERROR on " + (app.get('host') || "website") + " - " + opts.title,
      from: app.get('admin_email') || "no-reply@example.com",
      to: [app.get('error_email') || app.get('admin_email')],
      body: opts.message
    }, function(success, message) {
      if (success) {
        return typeof callback === "function" ? callback() : void 0;
      } else {
        console.error("ERROR EMAIL FAILED: ", message);
        return typeof callback === "function" ? callback("ERROR EMAIL FAILED: ", message) : void 0;
      }
    });
  };

  if (process.env.NODE_ENV === "production") {
    console.log('setting up production logging.'); 
    var sentry_url = app.get('sentry_url');

    if (sentry_url) {
      console.log('raven is being attached');
      raven = raven || require('raven');

      function onError(err, req, res, next) {
          // The error id is attached to `res.sentry` to be returned
          // and optionally displayed to the user for support.
          console.log('raven should have logged something.');
          res.statusCode = 500;
          res.end('<h1>Curses, it seems that BawkBox has broke.</h1><p>Your error reference number is ' + res.sentry + '</p>');
      }

      // The error handler must be before any other error middleware
      app.use(app.get('raven').errorHandler());

      //var client = new raven.Client(sentry_url);
      //client.patchGlobal();

      // Optional fallthrough error handler
      app.use(onError);

    } else { // Simple email based notification of errors.

      app.use(function(err, req, res, next) {
        var k, message, ref, ref1, v;
        message = "Details:\n========\n\n - location : " + req.host + req.originalUrl + " \n - xhr : " + req.xhr;
        message += "\nStack Trace:\n============\n\n\n###\n" + err.stack + "\n###\nRequest:\n========\n\n\n\n###\n" + req.method + " " + (req.protocol.toUpperCase()) + "/" + req.httpVersionMajor + "." + req.httpVersionMinor + "\n###";
        ref = req.headers;
        for (k in ref) {
          if (!hasProp.call(ref, k)) continue;
          v = ref[k];
          message += " - " + k + " : " + v + "\n";
        }
        if (req.session) {
          message += "\nSession:\n========\n";
          ref1 = req.session;
          for (k in ref1) {
            if (!hasProp.call(ref1, k)) continue;
            v = ref1[k];
            message += " - " + k + " : " + v + "\n";
          }
        }
        prod_error({
          title: err.name,
          message: message
        });
        return res.render('500');
      });
    }
  }

  app.get("/client_error", function(req, res) {
    var k, message, ref, v;
    if (!req.query.message) {
      return res.send({
        message: '/client_error: Failed - No error message specified.',
        success: false
      });
    }
    if (req.query.message === 'Script error.') {
      return res.send({
        message: 'CORS errors considered uninteresting.',
        success: false
      });
    }
    message = "DETAILS:\n========\n";
    ref = req.query;
    for (k in ref) {
      if (!hasProp.call(ref, k)) continue;
      v = ref[k];
      message += " - " + k + " : " + v + "\n";
    }

    /*
     * Only show errors on production sites.
     */
    if (process.env.NODE_ENV === 'production') {
      return prod_error({
        title: "Error Caught on Client",
        message: message
      }, function(err) {
        return res.send({
          success: true
        });

        /*
         * For dev sites, warn about possible config issue.
         */
      });
    } else {
      console.error('DEV SITE RECIEVED CLIENT ERROR:', req.query);
      return res.send({
        success: true,
        message: 'Client error ignored because this is a development site.'
      });
    }
  });
};
