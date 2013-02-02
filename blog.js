// Generated by CoffeeScript 1.4.0
(function() {
  var $, fs;

  $ = require('jquery');

  fs = require('fs');

  module.exports = function(opts) {
    var FORMS, NUM_PREVIEWS, PAGE_SIZE, app, common, common_lib, db, process_save, staff;
    common = require("./common")(opts);
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
          $or: [
            {
              _id: req.params.id
            }, {
              slug_field: req.params.id
            }
          ]
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
        email: req.session.email,
        images: ""
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
    process_save = function(req) {
      var convert_img, filePath, image, image_pos, index, obj_id, save_img, _i, _len, _ref;
      filePath = opts.upload_dir + "site/blog/";
      save_img = function(img, crop, img_height, img_width) {
        var newPath;
        newPath = filePath + img.name;
        return fs.readFile(img.path, function(err, data) {
          return fs.writeFile(newPath, data, function(err) {
            if (crop) {
              return convert_img(img.name, img_width, img_height, true, true, true);
            } else {
              return convert_img(img.name, img_width, img_height, false, true, true);
            }
          });
        });
      };
      convert_img = function(name, img_width, img_height, crop, resize, orient) {
        var auto_orient, convert_commands, crop_img_dim, newPath, scale_img_dim, size, thumbPath;
        if (name === '' || name === void 0 || name === 'undefined') {
          return true;
        }
        crop_img_dim = function(w, h) {
          var height, ratio, width;
          ratio = 1.31645569620253;
          width = 0;
          height = 0;
          if (w / h < ratio) {
            width = Math.round(w);
            height = Math.round(w / ratio);
          } else {
            height = Math.round(h);
            width = Math.round(h * ratio);
          }
          return [width, height];
        };
        scale_img_dim = function() {
          var maxH, maxW;
          maxW = 800;
          maxH = 500;
          return " -resize '" + maxW + 'x' + maxH + "' ";
        };
        auto_orient = function() {
          return " -auto-orient ";
        };
        thumbPath = filePath + name;
        newPath = filePath + name;
        convert_commands = '';
        size = [img_width, img_height];
        if (crop) {
          thumbPath = filePath + 'thumb-' + name;
          size = crop_img_dim(size[0], size[1]);
          convert_commands += ' -gravity center -crop ' + size[0] + 'x' + size[1] + '+0+0 ';
        }
        if (resize) {
          convert_commands += scale_img_dim();
        }
        if (orient) {
          convert_commands += auto_orient();
        }
        console.log("Here we go: " + 'convert ' + newPath + convert_commands + thumbPath);
        return common_lib.syscall('convert ' + newPath + convert_commands + thumbPath);
      };
      obj_id = {
        _id: req.params.id
      };
      req.body.content = req.body.content.replace(/\r\n/g, '<br>');
      _ref = [1, 2, 3, 4, 5, 6];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        index = _ref[_i];
        image_pos = 'image_' + index + '_pos';
        if (req.body[image_pos] === '1') {
          req.body[image_pos] = '';
        }
        image = "image" + req.body[image_pos];
        if (!(req.body[image_pos] === 'undefined' || req.body[image_pos] === void 0)) {
          if (req.files[image].size !== 0) {
            req.body[image] = req.files[image].name;
          } else {
            req.body[image] = req.body["prev_image" + req.body[image_pos]];
            if (req.body['crop_' + index]) {
              convert_img(req.body[image], req.body['width_' + image], req.body['height_' + image], true, true, true);
            }
          }
        }
      }
      return common_lib.syscall('mkdir -p ' + filePath, function() {
        var idx, _j, _len1, _ref1, _results;
        if (req.files.image.size !== 0) {
          save_img(req.files.image, req.body.crop_1, req.body.height_image, req.body.width_image);
        }
        _ref1 = [2, 3, 4, 5, 6];
        _results = [];
        for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
          idx = _ref1[_j];
          if (req.files["image" + idx].size !== 0) {
            _results.push(save_img(req.files["image" + idx], req.body["crop_" + idx], req.body["height_image" + idx], req.body["width_image" + idx]));
          } else {
            _results.push(void 0);
          }
        }
        return _results;
      });
    };
    app.post("/admin/blog/:id", staff, function(req, res) {
      process_save(req);
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
    app.post("/admin/add-blog", staff, function(req, res) {
      process_save(req);
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
    return app.get("/admin/blog/:id/delete", staff, function(req, res) {
      return db.collection('blog').remove({
        _id: req.params.id
      }, function(err, rec) {
        return res.redirect("/admin/blog");
      });
    });
  };

}).call(this);
