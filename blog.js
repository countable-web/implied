//@ sourceMappingURL=blog.map
// Generated by CoffeeScript 1.6.1
(function() {
  var $, async, fs;

  $ = require('jquery');

  fs = require('fs');

  async = require('async');

  module.exports = function(opts) {
    var FORMS, NUM_PREVIEWS, PAGE_SIZE, app, common, common_lib, db, photos, process_save, staff;
    common = require("./common")(opts);
    photos = require('./photos');
    staff = common.staff;
    app = opts.app;
    db = opts.db;
    common_lib = require('../../lib/common');
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
        image: 1,
        edit_1: 1
      }).sort({
        pub_date: -1
      }).limit(NUM_PREVIEWS).toArray(function(err, blog_teasers) {
        return db.collection('blog').find(filter, {
          title: 1,
          image: 1,
          pub_date: 1,
          teaser: 1,
          edit_1: 1
        }).sort({
          pub_date: -1
        }).skip(PAGE_SIZE * (pagenum - 1)).limit(PAGE_SIZE + 1).toArray(function(err, blog_articles) {
          return res.render('blog/blog-entries', {
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
          $or: [
            {
              _id: req.params.id
            }, {
              slug_field: req.params.id
            }
          ]
        }, function(err, entry) {
          if (err) {
            console.error(err);
          }
          return res.render("blog/blog-entry", {
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
        email: req.session.email,
        images: "",
        category: false
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
      return db.collection('blog').find().sort({
        title: 1
      }).toArray(function(err, entries) {
        return res.render("admin/blog-list", {
          req: req,
          email: req.session.email,
          entries: entries
        });
      });
    });
    app.get("/admin/blog/:id", staff, function(req, res) {
      return db.collection('blog').findOne({
        $or: [
          {
            _id: req.params.id
          }, {
            slug_field: req.params.id
          }
        ]
      }, function(err, rec) {
        return res.render("admin/blog-add", {
          title: req.params.collection,
          req: req,
          form: FORMS['blog'],
          email: req.session.email,
          rec: rec,
          category: rec.category
        });
      });
    });
    process_save = function(req, callback) {
      var convert_task_arr, entry, filePath, idx, img, obj_id, pos, save_img, save_task_arr, _i, _len, _ref;
      filePath = opts.upload_dir + "site/blog/";
      entry = req.body;
      save_img = function(args, callback) {
        var newPath;
        newPath = filePath + args.img.name;
        return fs.readFile(args.img.path, function(err, data) {
          return fs.writeFile(newPath, data, function(err) {
            if (args.crop) {
              return photos.convert_img({
                filePath: filePath,
                name: args.img.name,
                img_width: args.img_width,
                img_height: args.img_height,
                crop: true,
                resize: true,
                orient: true,
                effect: args.effect
              }, callback);
            } else {
              return photos.convert_img({
                filePath: filePath,
                name: args.img.name,
                img_width: args.img_width,
                img_height: args.img_height,
                crop: false,
                resize: true,
                orient: true,
                effect: args.effect
              }, callback);
            }
          });
        });
      };
      obj_id = {
        _id: req.params.id
      };
      entry.content = entry.content.replace(/\r\n/g, '<br>');
      save_task_arr = [];
      convert_task_arr = [];
      idx = 1;
      _ref = ["image", "image2", "image3", "image4", "image5", "image6"];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        img = _ref[_i];
        pos = 'image_' + idx + '_pos';
        if (!(entry[pos] === 'undefined' || entry[pos] === void 0)) {
          if (req.files[img].size !== 0) {
            entry[img] = req.files[img].name;
          } else {
            if (entry[pos] === '1') {
              entry[pos] = "";
            }
            entry[img] = entry["prev_image" + entry[pos]];
            if (req.body['edit_' + idx]) {
              if (entry[img]) {
                convert_task_arr.push({
                  filePath: filePath,
                  name: entry[img],
                  img_width: entry['width_' + img],
                  img_height: entry['height_' + img],
                  crop: entry['crop_' + idx],
                  resize: true,
                  orient: true,
                  effect: entry["effects_" + idx]
                });
              }
            }
          }
        }
        idx = idx + 1;
      }
      return common_lib.syscall('mkdir -p ' + filePath, function() {
        var _j, _len1, _ref1;
        idx = 1;
        _ref1 = ["", "2", "3", "4", "5", "6"];
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          img = _ref1[_j];
          if (req.files["image" + img].size !== 0) {
            save_task_arr.push({
              filePath: filePath,
              img: req.files["image" + img],
              crop: req.body["crop_" + idx],
              img_height: req.body["height_image" + img],
              img_width: req.body["width_image" + img],
              resize: true,
              orient: true,
              effect: req.body['effects_' + idx]
            });
          }
          idx = idx + 1;
        }
        return async.concatSeries(save_task_arr, save_img, function(err, results) {
          if (err) {
            console.error("FAILED TO SAVE IMAGES - ", err);
          }
          return async.concatSeries(convert_task_arr, photos.convert_img, function(err, results) {
            if (err) {
              console.error("ERROR CONVERTING IMAGES: ", err);
            }
            return callback();
          });
        });
      });
    };
    app.post("/admin/blog/:id", staff, function(req, res) {
      return process_save(req, function() {
        delete req.body._id;
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
    });
    app.post("/admin/add-blog", staff, function(req, res) {
      return process_save(req, function() {
        if (!req.body.slug_field) {
          return fail('Slug is required.');
        } else {
          req.body._id = req.body.slug_field;
        }
        return db.collection('blog').findOne({
          _id: req.body._id
        }, function(err, entry) {
          if (entry) {
            return fail('Slug is already used.');
          } else {
            return db.collection("blog").insert(req.body, function(err, entry) {
              if (err) {
                console.error(err);
              }
              return res.redirect('/admin/blog');
            });
          }
        });
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
