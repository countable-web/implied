$ = require 'jquery'
fs = require 'fs'

module.exports = (opts)->
  
  common = require("./common") opts
  staff = common.staff

  app = opts.app
  db = opts.db
  common_lib = require '../../lib/common'


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
      filter.category = req.query.category
    pagenum = 1*(req.query.page or 1)
    db.collection('blog').find({public_visible: 'on'}, {title:1, image:1}).sort({pub_date : -1}).limit(NUM_PREVIEWS).toArray (err, blog_teasers) ->
      db.collection('blog').find(filter, {title:1, image:1, pub_date:1, teaser:1}).sort({pub_date : -1}).skip(PAGE_SIZE*(pagenum-1)).limit(PAGE_SIZE+1).toArray (err, blog_articles) ->
        res.render 'blog-entries',
          req: req
          email: req.session.email
          blog_articles: blog_articles[0...PAGE_SIZE]
          blog_teasers: blog_teasers
          blog_page_number: pagenum
          blog_has_next_page: blog_articles.length > PAGE_SIZE

  app.get "/blog/:id", (req,res) ->
    db.collection('blog').find({public_visible: 'on'}, {title:1, image:1}).sort({pub_date : -1}).limit(NUM_PREVIEWS).toArray (err, blog_teasers) ->
      db.collection('blog').findOne {_id: req.params.id}, (err, entry)->
        console.log err if err
        console.log "This is my entry: ", entry

        res.render "blog-entry",
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

  app.get "/admin/blog-image-edit/:photo", staff, (req, res) ->
    res.render "admin/blog-image-edit",
      req: req
      rec: {}
      email: req.session.email
      image: req.params.photo


  app.get "/blog-action/subscribe", (req, res)->
    if req.query.email
      subscriber=
        blog: true
        email: req.query.email

      db.collection("subscribers").update subscriber, subscriber, true, (err, entry)->
        if err then console.error err
        res.send {success: true}

  app.get "/admin/blog", staff, (req, res) ->
    db.collection('blog').find().toArray (err, entries)->
      res.render "admin/blog-list",
        req: req
        email: req.session.email
        entries: entries
  
  app.get "/admin/blog/:id", staff, (req, res) ->
    db.collection('blog').findOne {_id: req.params.id}, (err, rec) ->
      res.render "admin/blog-add",
        title: req.params.collection
        req: req
        form: FORMS['blog']
        email: req.session.email
        rec: rec


  process_save = (req)->
    filePath = opts.upload_dir + "site/blog/"

    crop_img = (img_name, img_height, img_width)->
      thumbPath = filePath + 'thumb_' + img_name
      newPath = filePath + img_name
      cal_dim = (w, h)->
        ratio = 1.31645569620253
        width = 0
        height = 0
        if w / h < ratio
          width = parseInt(w, 10)
          height = parseInt(w / ratio, 10)
        else
          height = parseInt h, 10
          width = parseInt h * ratio, 10
        return width + "x" + height

      common_lib.syscall 'convert ' + newPath + ' -gravity center -crop ' + cal_dim(img_width, img_height) + '+0+0 ' + thumbPath

    save_img = (img, crop, img_height, img_width)->
      fs.readFile img.path, (err, data) ->
        newPath = filePath + img.name
        fs.writeFile newPath, data, (err)->
          if crop
            crop_img(img.name, img_height, img_width)

    obj_id = {_id: req.params.id}
    req.body.content = req.body.content.replace /\r\n/g, '<br>'
    if req.body.slug_field and req.body.slug_field.length
      req.body._id = req.body.slug_field

    for index in [1, 2, 3, 4, 5, 6]
      image_pos = 'image_' + index + '_pos'

      if req.body[image_pos] is '1'
        req.body[image_pos] = ''

      image = "image" + req.body[image_pos]

      unless req.body[image_pos] is 'undefined'
        unless req.files[image].size is 0
          req.body[image] = req.files[image].name
        else 
          req.body[image] = req.body.prev_image
          if req.body['crop_' + index]
            crop_img(req.body[image], req.body['height_' + image], req.body['width_' + image])

    common_lib.syscall 'mkdir -p ' + filePath, ->
      save_img(req.files.image, req.body.crop_1, req.body.height_image, req.body.width_image)
      save_img(req.files.image2, req.body.crop_2, req.body.height_image2, req.body.width_image2)
      save_img(req.files.image3, req.body.crop_3, req.body.height_image3, req.body.width_image3)
      save_img(req.files.image4, req.body.crop_4, req.body.height_image4, req.body.width_image4)
      save_img(req.files.image5, req.body.crop_5, req.body.height_image5, req.body.width_image5)
      save_img(req.files.image6, req.body.crop_6, req.body.height_image6, req.body.width_image6)

    
  app.post "/admin/blog/:id", staff, (req, res) ->
    process_save req
    db.collection('blog').update {_id: req.params.id}, req.body, false, (err) ->
      if err then return res.send {success:false, error: err}
      res.redirect '/admin/blog'

  app.post "/admin/add-blog", staff, (req, res)->
    process_save req

    if not req.body.slug_field
      obj_id = new ObjectId()
      req.body._id = obj_id.toString(16)

    db.collection("blog").insert req.body, (err, entry)->
      if err then console.error err
      res.redirect '/admin/blog'

  app.get "/admin/blog/:id/delete", staff, (req, res) ->
    db.collection('blog').remove {_id: req.params.id}, (err, rec) ->
      res.redirect "/admin/blog"