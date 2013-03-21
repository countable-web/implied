//@ sourceMappingURL=users.map
// Generated by CoffeeScript 1.6.1
(function() {
  var md5, uuid;

  md5 = require('MD5');

  uuid = require('node-uuid');

  module.exports = function(opts) {
    var Users, app, db, flash, goto_next, server_path, statics, _ref;
    if ((_ref = opts.salt) == null) {
      opts.salt = 'secret-the-cat';
    }
    app = opts.app;
    db = opts.db;
    Users = db.collection('users');
    statics = function(arr) {
      return arr.forEach(function(item) {
        return app.get('/' + item, function(req, res) {
          return res.render(item, {
            req: req
          });
        });
      });
    };
    statics(['signup', 'login', 'reset-password-confirm', 'reset-password-submit']);
    goto_next = function(req, res) {
      return res.redirect(req.query.then || req.body.then || '/');
    };
    flash = function(req, message_type, message) {
      var m, _base, _ref1, _ref2;
      if (message_type && message) {
        m = (_ref1 = (_base = req.session).messages) != null ? _ref1 : _base.messages = {};
        if ((_ref2 = m[message_type]) == null) {
          m[message_type] = [];
        }
        return m[message_type].push(message);
      }
    };
    app.post("/login", function(req, res) {
      return Users.findOne({
        email: req.body.email,
        $or: [
          {
            password: req.body.password
          }, {
            password: md5(req.body.password + opts.salt)
          }
        ]
      }, function(err, user) {
        if (user) {
          req.session.email = user.email;
          req.session.admin = user.admin;
          flash(req, "success", "You've been logged in.");
          return goto_next(req, res);
        } else {
          flash(req, "error", "Email or password incorrect.");
          return res.redirect(req.body.onerror || req.path);
        }
      });
    });
    app.get("/logout", function(req, res) {
      req.session.email = null;
      flash(req, "success", "You've been safely logged out");
      return goto_next(req, res);
    });
    app.post("/signup", function(req, res) {
      if (req.body.email && req.body.password) {
        req.body.password = md5(req.body.password + opts.salt);
        if (!/^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/.test(req.body.email)) {
          flash(req, "error", "Invalid email address.");
          return res.render('signup', {
            req: req
          });
        }
        return Users.find({
          email: req.body.email
        }).toArray(function(err, users) {
          if (users.length === 0) {
            Users.insert(req.body, function(err, user) {
              req.session.email = user.email;
              req.session.admin = user.admin;
              return goto_next(req, res);
            });
            if (opts.mailer && opts.signup) {
              return typeof opts.mailer === "function" ? opts.mailer({
                to: req.body.email,
                subject: opts.signup.subject || "Welcome!",
                body: opts.signup.body || ("Thankyou for signing up at " + server_path(req))
              }) : void 0;
            }
          } else {
            flash(req, "error", "That user already exists.");
            return res.render('signup', {
              req: req
            });
          }
        });
      } else {
        flash(req, "error", "Please enter a username and password.");
        return res.render('signup', {
          req: req
        });
      }
    });
    server_path = function(req) {
      var url;
      url = req.protocol + "://" + req.host;
      if (req.port && req.port !== 80) {
        url += ":" + req.port;
      }
      return url;
    };
    app.post("/reset-password-submit", function(req, res) {
      return Users.findOne({
        email: req.body.email
      }, function(err, user) {
        var token;
        if (user) {
          token = uuid.v4();
          Users.update({
            _id: user._id
          }, {
            $set: {
              password_reset_token: token
            }
          });
          if (typeof opts.mailer === "function") {
            opts.mailer({
              to: user.email,
              subject: "Password Reset",
              body: "Go here to reset your password: http://" + opts.host + "/reset-password-confirm?token=" + token
            });
          }
          console.log('sent');
          flash(req, "message", "You've been sent an email with instructions on resetting your password.");
          return goto_next(req, res);
        } else {
          return flash(req, "error", "No user with that email address was found.");
        }
      });
    });
    return app.post("/reset-password-confirm", function(req, res) {
      var query;
      if (req.session.email) {
        query = {
          email: req.session.email
        };
      } else {
        query = {
          password_reset_token: req.query.token
        };
      }
      return Users.update(query, {
        $set: {
          password: req.body.password
        }
      }, function(err, user) {
        if (err) {
          flash(req, 'error', 'Password reset failed');
        } else {
          flash(req, 'success', 'Password was reset');
        }
        return goto_next(req, res);
      });
    });
  };

}).call(this);
