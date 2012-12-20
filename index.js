(function() {
  var fs, md5, uuid;
  md5 = require('MD5');
  uuid = require('node-uuid');
  fs = require('fs');
  module.exports.users = {
    init: function(opts) {
      var Users, app, db, goto_next, server_path, statics, _ref;
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
            if (typeof req.flash === "function") {
              req.flash("success", "You've been logged in.");
            }
            return goto_next(req, res);
          } else {
            if (typeof req.flash === "function") {
              req.flash("error", "Email or password incorrect.");
            }
            return res.redirect(req.path);
          }
        });
      });
      app.get("/logout", function(req, res) {
        req.session.email = null;
        if (typeof req.flash === "function") {
          req.flash("success", "You've been safely logged out");
        }
        return goto_next(req, res);
      });
      app.post("/signup", function(req, res) {
        if (req.body.email && req.body.password) {
          req.body.password = md5(req.body.password + opts.salt);
          return Users.find({
            email: req.body.email
          }).toArray(function(err, users) {
            if (users.length === 0) {
              return Users.insert(req.body, function(err, user) {
                req.session.email = user.email;
                return goto_next(req, res);
              });
            } else {
              if (typeof req.flash === "function") {
                req.flash("error", "That user already exists.");
              }
              return res.render('signup', {
                req: req
              });
            }
          });
        } else {
          if (typeof req.flash === "function") {
            req.flash("error", "Please enter a username and password.");
          }
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
            if (typeof req.flash === "function") {
              req.flash("message", "You've been sent an email with instructions on resetting your password.");
            }
            return goto_next(req, res);
          } else {
            return typeof req.flash === "function" ? req.flash("error", "No user with that email address was found.") : void 0;
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
            req.flash('error', 'Password reset failed');
          } else {
            req.flash('success', 'Password was reset');
          }
          return goto_next(req, res);
        });
      });
    }
  };
  module.exports.admin = {
    init: function(opts) {
      var FORMS, app, db, forms, staff, _ref;
      if ((_ref = opts.login_url) == null) {
        opts.login_url = "/login";
      }
      app = opts.app;
      db = opts.db;
      forms = opts.forms || {};
      staff = function(req, res, next) {
        if (req.session.email) {
          return db.collection('users').findOne({
            email: req.session.email,
            admin: true
          }, function(err, user) {
            if (user) {
              return next();
            } else {
              if (typeof req.flash === "function") {
                req.flash('Not authorized.');
              }
              return res.redirect(opts.login_url + "?then=" + req.path);
            }
          });
        } else {
          if (typeof req.flash === "function") {
            req.flash('Not authorized.');
          }
          return res.redirect(opts.login_url + "?then=" + req.path);
        }
      };
      app.get("/blog", function(req, res) {
        return db.collection('blog').find({
          public_visible: 'checked'
        }).sort({
          pub_date: -1
        }).limit(3).toArray(function(err, entries) {
          return res.render('blog-entries', {
            req: req,
            email: req.session.email,
            entries: entries
          });
        });
      });
      app.get("/blog/:id", function(req, res) {
        return db.collection('blog').find({
          public_visible: 'checked'
        }, {
          title: 1,
          image: 1
        }).sort({
          pub_date: -1
        }).limit(3).toArray(function(err, entries) {
          return db.collection('blog').findOne({
            _id: req.params.id
          }, function(err, rec) {
            if (err) {
              console.log(err);
            }
            return res.render("blog-entry", {
              req: req,
              entries: entries,
              email: req.session.email,
              rec: rec
            });
          });
        });
      });
      app.get("/admin", staff, function(req, res) {
        return res.render('admin/admin', {
          req: req,
          email: req.session.email
        });
      });
      app.get("/admin/add-blog", staff, function(req, res) {
        return res.render("admin/blog-add", {
          req: req,
          rec: {},
          email: req.session.email
        });
      });
      app.post("/admin/add-blog", staff, function(req, res) {
        var obj_id;
        req.body.content = req.body.content.replace(/\r\n/g, '<br>');
        if (req.body.slug_field && req.body.slug_field.length) {
          req.body._id = req.body.slug_field;
        } else {
          obj_id = new ObjectId();
          req.body._id = obj_id.toString(16);
        }
        if (req.files.image) {
          req.body.image = req.files.image.name;
          fs.readFile(req.files.image.path, function(err, data) {
            var newPath;
            newPath = opts.upload_dir + "site/blog/" + req.files.image.name;
            return fs.writeFile(newPath, data);
          });
        }
        return db.collection("blog").insert(req.body, function(err, entry) {
          if (err) {
            console.error(err);
          }
          return res.redirect('/admin/blog');
        });
      });
      app.get("/admin/blog", staff, function(req, res) {
        return db.collection('blog').find().toArray(function(err, entries) {
          return res.render("admin/blog-list", {
            req: req,
            email: req.session.email,
            entries: entries
          });
        });
      });
      app.get("/admin/blog/:id", staff, function(req, res) {
        return db.collection('blog').findOne({
          _id: req.params.id
        }, function(err, rec) {
          return res.render("admin/blog-add", {
            title: req.params.collection,
            req: req,
            form: FORMS['blog'],
            email: req.session.email,
            rec: rec
          });
        });
      });
      app.post("/admin/blog/:id", staff, function(req, res) {
        var obj_id;
        obj_id = {
          _id: req.params.id
        };
        req.body.content = req.body.content.replace(/\r\n/g, '<br>');
        console.log('IMG', req.files.image);
        console.log(req.files.image.size > 0);
        if (req.files.image && req.files.image.size > 0) {
          req.body.image = req.files.image.name;
          fs.readFile(req.files.image.path, function(err, data) {
            var newPath;
            newPath = opts.upload_dir + "site/blog/" + req.files.image.name;
            return fs.writeFile(newPath, data);
          });
        }
        return db.collection('blog').update({
          _id: req.params.id
        }, {
          $set: req.body
        }, false, function(err) {
          if (err) {
            return res.send({
              success: false,
              error: err
            });
          }
          return res.redirect('/admin/blog');
        });
      });
      app.get("/admin/blog/:id/delete", staff, function(req, res) {
        return db.collection('blog').remove({
          _id: req.params.id
        }, function(err, rec) {
          return res.redirect("/admin/blog");
        });
      });
      app.get("/admin/:collection", staff, function(req, res) {
        return db.collection(req.params.collection).find().toArray(function(err, records) {
          return res.render("admin-list", {
            title: req.params.collection,
            form: forms[req.params.collection],
            req: req,
            email: req.session.email,
            records: records
          });
        });
      });
      app.get("/admin/:collection/:id", staff, function(req, res) {
        return db.collection(req.params.collection).findOne({
          _id: new ObjectId(req.params.id)
        }, function(err, rec) {
          return res.render("admin-object", {
            title: req.params.collection,
            req: req,
            form: forms[req.params.collection],
            email: req.session.email,
            rec: rec
          });
        });
      });
      app.post("/admin/:collection/:id", staff, function(req, res) {
        return db.collection(req.params.collection).update({
          _id: new ObjectId(req.params.id)
        }, {
          $set: req.body
        }, function(err) {
          return res.redirect('/admin/' + req.params.collection);
        });
      });
      return FORMS = {
        pages: {
          print: 'paths',
          fields: [
            {
              name: 'title'
            }, {
              name: 'path'
            }, {
              name: 'content',
              type: 'textarea'
            }, {
              name: 'meta'
            }
          ]
        },
        blog: {
          print: 'paths',
          fields: [
            {
              name: 'pub_date'
            }, {
              name: 'name'
            }, {
              name: 'title'
            }, {
              name: 'content',
              type: 'textarea'
            }, {
              name: 'teaser'
            }, {
              name: 'slug_field'
            }
          ]
        }
      };
    }
  };
}).call(this);
