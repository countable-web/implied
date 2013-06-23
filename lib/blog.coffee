
path = require 'path'
fs = require 'fs'
async = require 'async'
util = require '../util'

module.exports = (app)->
  
  photos = require './photos'
  upload_dir = app.get('upload_dir')
  
  staff = app.get('implied').users.staff
  
  unless staff
    throw 'Users module is required'
  
  db = app.get('db')

  PAGE_SIZE = 3
  NUM_PREVIEWS = 5
  FORMS =
    blog:
      print: 'paths'
      fields: [
          name: 'pub_date'
        ,
          name: 'name'
        ,
          name: 'title'
        ,
          name: 'content'
          type: 'textarea'
        ,
          name: 'teaser'
        ,
          name: 'slug_field'
      ]
  
  app.get "/blog", (req, res) ->
    filter =
      public_visible: 'on'
    if req.query.category
      #filter.category = { $all: [req.query.category] }
      filter.category = req.query.category
    pagenum = 1*(req.query.page or 1)
    db.collection('blog').find({public_visible: 'on'}, {title:1, image:1, edit_1:1}).sort({pub_date : -1}).limit(NUM_PREVIEWS).toArray (err, blog_teasers) ->
      db.collection('blog').find(filter, {title:1, image:1, pub_date:1, teaser:1, edit_1:1}).sort({pub_date : -1}).skip(PAGE_SIZE*(pagenum-1)).limit(PAGE_SIZE+1).toArray (err, blog_articles) ->
        res.render 'blog/blog-entries',
          req: req
          email: req.session.email
          blog_articles: blog_articles[0...PAGE_SIZE]
          blog_teasers: blog_teasers
          blog_page_number: pagenum
          blog_has_next_page: blog_articles.length > PAGE_SIZE

  app.get "/blog/:id", (req,res) ->
    db.collection('blog').find({public_visible: 'on'}, {title:1, image:1}).sort({pub_date : -1}).limit(NUM_PREVIEWS).toArray (err, blog_teasers) ->
      db.collection('blog').findOne {$or: [{_id: req.params.id}, {slug_field: req.params.id}]}, (err, entry)->
        console.error err if err

        unless entry
          res.status(404).render '404'
        else
          res.render "blog/blog-entry",
            req: req
            blog_teasers: blog_teasers
            email: req.session.email
            entry: entry

  app.get "/admin/add-blog", staff, (req, res) ->
    res.render "admin/blog-add",
      req: req
      rec: {}
      email: req.session.email
      images: ""
      category: false

  app.get "/blog-action/subscribe", (req, res)->
    if req.query.email
      subscriber=
        blog: true
        email: req.query.email

      db.collection("subscribers").update subscriber, subscriber, true, (err, entry)->
        if err then console.error err
        res.send {success: true}

  app.get "/admin/blog", staff, (req, res) ->
    db.collection('blog').find().sort({title: 1}).toArray (err, entries)->
      res.render "admin/blog-list",
        req: req
        email: req.session.email
        entries: entries
  
  app.get "/admin/blog/:id", staff, (req, res) ->
    db.collection('blog').findOne {$or: [{_id: req.params.id}, {slug_field: req.params.id}]}, (err, rec) ->
      res.render "admin/blog-add",
        title: req.params.collection
        req: req
        form: FORMS['blog']
        email: req.session.email
        rec: rec
        category: rec.category


  process_save = (req, callback)->
    filePath = path.join(upload_dir, "site/blog/")
    entry = req.body

    save_img = (args, callback)->
      newPath = filePath + args.img.name
      fs.readFile args.img.path, (err, data) ->
        fs.writeFile newPath, data, (err)->
          if args.crop
            photos.convert_img { filePath: filePath, name: args.img.name, img_width: args.img_width, img_height: args.img_height, crop: true, resize: true, orient: true, effect: args.effect }, callback
          else
            photos.convert_img { filePath: filePath, name: args.img.name, img_width: args.img_width, img_height: args.img_height, crop: false, resize: true, orient: true, effect: args.effect }, callback

    obj_id = {_id: req.params.id}
    entry.content = entry.content.replace /\r\n/g, '<br>'

    save_task_arr = []
    convert_task_arr = []
    idx = 1
    for img in ["image", "image2", "image3", "image4", "image5", "image6"]
      pos = 'image_' + idx + '_pos'

      unless entry[pos] is 'undefined' or entry[pos] is undefined
        unless req.files[img].size is 0
          entry[img] = req.files[img].name
        else 
          entry[pos] = "" if entry[pos] is '1'
          entry[img] = entry["prev_image" + entry[pos]]
          if req.body['edit_' + idx]
            if entry[img]
              convert_task_arr.push {filePath: filePath, name: entry[img], img_width: entry['width_' + img], img_height: entry['height_' + img], crop: entry['crop_' + idx], resize: true, orient: true, effect: entry["effects_" + idx]}
      idx = idx + 1

    util.syscall 'mkdir -p ' + filePath, ->
      idx = 1
      for img in ["", "2", "3", "4", "5", "6"]
        unless req.files["image" + img].size is 0
          save_task_arr.push {filePath: filePath, img: req.files["image" + img], crop: req.body["crop_" + idx], img_height: req.body["height_image" + img], img_width: req.body["width_image" + img], resize: true, orient: true, effect: req.body['effects_' + idx]}
        idx = idx + 1

      async.concatSeries save_task_arr, save_img, (err, results)->
        if err then console.error "FAILED TO SAVE IMAGES - ", err
        async.concatSeries convert_task_arr, photos.convert_img, (err, results)->
          if err then console.error "ERROR CONVERTING IMAGES: ", err
          callback()

  app.post "/admin/blog/:id", staff, (req, res) ->
    process_save req, ()->
      delete req.body._id
      db.collection('blog').update {_id: req.params.id}, req.body, false, (err) ->
        if err then return res.send {success:false, error: err}
        res.redirect '/admin/blog'

  app.post "/admin/add-blog", staff, (req, res)->
    process_save req, ()->
      if not req.body.slug_field
        return fail 'Slug is required.'
      else
        req.body._id = req.body.slug_field

      db.collection('blog').findOne {_id: req.body._id}, (err, entry)->
        if entry
          return fail 'Slug is already used.'
        else
          db.collection("blog").insert req.body, (err, entry)->
            if err then console.error err
            res.redirect '/admin/blog'

  app.get "/admin/blog/:id/delete", staff, (req, res) ->
    db.collection('blog').remove {_id: req.params.id}, (err, rec) ->
      res.redirect "/admin/blog"
