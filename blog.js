(function() {
  var $, fs;
  $ = require('jquery');
  fs = require('fs');
  module.exports = function(opts) {
    var FORMS, NUM_PREVIEWS, PAGE_SIZE, app, common, db, process_save, staff;
    common = require("./common")(opts);
    staff = common.staff;
    app = opts.app;
    db = opts.db;
    PAGE_SIZE = 3;
    NUM_PREVIEWS = 5;
    FORMS = {
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
    app.get("/blog", function(req, res) {
      var filter, pagenum;
      filter = {
        public_visible: 'on'
      };
      if (req.query.category) {
        filter.category = req.query.category;
      }
      pagenum = 1 * (req.query.page || 1);
      return db.collection('blog').find({
        public_visible: 'on'
      }, {
        title: 1,
        image: 1
      }).sort({
        pub_date: -1
      }).limit(NUM_PREVIEWS).toArray(function(err, blog_teasers) {
        return db.collection('blog').find(filter, {
          title: 1,
          image: 1,
          pub_date: 1,
          teaser: 1
        }).sort({
          pub_date: -1
        }).skip(PAGE_SIZE * (pagenum - 1)).limit(PAGE_SIZE + 1).toArray(function(err, blog_articles) {
          return res.render('blog-entries', {
            req: req,
            email: req.session.email,
            blog_articles: blog_articles.slice(0, PAGE_SIZE),
            blog_teasers: blog_teasers,
            blog_page_number: pagenum,
            blog_has_next_page: blog_articles.length > PAGE_SIZE
          });
        });
      });
    });
    app.get("/blog/:id", function(req, res) {
      return db.collection('blog').find({
        public_visible: 'on'
      }, {
        title: 1,
        image: 1
      }).sort({
        pub_date: -1
      }).limit(NUM_PREVIEWS).toArray(function(err, blog_teasers) {
        return db.collection('blog').findOne({
          _id: req.params.id
        }, function(err, entry) {
          if (err) {
            console.log(err);
          }
          return res.render("blog-entry", {
            req: req,
            blog_teasers: blog_teasers,
            email: req.session.email,
            entry: entry
          });
        });
      });
    });
    app.get("/admin/add-blog", staff, function(req, res) {
      return res.render("admin/blog-add", {
        req: req,
        rec: {},
        email: req.session.email
      });
    });
    app.get("/blog-action/subscribe", function(req, res) {
      var subscriber;
      if (req.query.email) {
        subscriber = {
          blog: true,
          email: req.query.email
        };
        return db.collection("subscribers").update(subscriber, subscriber, true, function(err, entry) {
          if (err) {
            console.error(err);
          }
          return res.send({
            success: true
          });
        });
      }
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
    process_save = function(req) {
      var obj_id;
      obj_id = {
        _id: req.params.id
      };
      req.body.content = req.body.content.replace(/\r\n/g, '<br>');
      if (req.body.slug_field && req.body.slug_field.length) {
        req.body._id = req.body.slug_field;
      }
      if (req.files.image && req.files.image.size > 0) {
        req.body.image = req.files.image.name;
        return fs.readFile(req.files.image.path, function(err, data) {
          var newPath;
          newPath = opts.upload_dir + "site/blog/" + req.files.image.name;
          return fs.writeFile(newPath, data);
        });
      }
    };
    app.post("/admin/blog/:id", staff, function(req, res) {
      process_save(req);
      return db.collection('blog').update({
        _id: req.params.id
      }, req.body, false, function(err) {
        if (err) {
          return res.send({
            success: false,
            error: err
          });
        }
        return res.redirect('/admin/blog');
      });
    });
    app.post("/admin/add-blog", staff, function(req, res) {
      var obj_id;
      process_save(req);
      if (!req.body.slug_field) {
        obj_id = new ObjectId();
        req.body._id = obj_id.toString(16);
      }
      return db.collection("blog").insert(req.body, function(err, entry) {
        if (err) {
          console.error(err);
        }
        return res.redirect('/admin/blog');
      });
    });
    return app.get("/admin/blog/:id/delete", staff, function(req, res) {
      return db.collection('blog').remove({
        _id: req.params.id
      }, function(err, rec) {
        return res.redirect("/admin/blog");
      });
    });
  };
}).call(this);
