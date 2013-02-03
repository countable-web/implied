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
      #filter.category = { $all: [req.query.category] }
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
      db.collection('blog').findOne {$or: [{_id: req.params.id}, {slug_field: req.params.id}]}, (err, entry)->
        console.log err if err

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


  process_save = (req)->
    filePath = opts.upload_dir + "site/blog/"
    save_img = (img, crop, img_height, img_width)->
      newPath = filePath + img.name
      fs.readFile img.path, (err, data) ->
        fs.writeFile newPath, data, (err)->
          if crop
            convert_img(img.name, img_width, img_height, true, true, true)
          else
            convert_img(img.name, img_width, img_height, false, true, true)

    convert_img = (name, img_width, img_height, crop, resize, orient)->
      if name is '' or name is undefined or name is 'undefined'
        return true
      crop_img_dim = (w, h)->
        ratio = 1.31645569620253
        width = 0
        height = 0
        if w / h < ratio
          width = Math.round w
          height = Math.round w / ratio
        else
          height = Math.round h
          width = Math.round h * ratio
        return [width, height]

      scale_img_dim = ()->
        maxW = 800
        maxH = 500
        return " -resize '" + maxW + 'x' + maxH + "' "

      auto_orient = ()->
        return " -auto-orient "

      thumbPath = filePath + name
      newPath = filePath + name
      convert_commands = ''
      size = [img_width, img_height]

      if crop
        thumbPath = filePath + 'thumb-' + name
        size = crop_img_dim(size[0], size[1])
        convert_commands += ' -gravity center -crop ' + size[0] + 'x' + size[1] + '+0+0 '

      if resize
        convert_commands += scale_img_dim()

      if orient
        convert_commands += auto_orient()
      newPath = '"' + newPath + '"'
      thumbPath = '"' + thumbPath + '"'
      console.log "Here we go: " + 'convert ' + newPath + convert_commands + thumbPath
      common_lib.syscall 'convert ' + newPath + convert_commands + thumbPath

    obj_id = {_id: req.params.id}
    req.body.content = req.body.content.replace /\r\n/g, '<br>'

    for index in [1, 2, 3, 4, 5, 6]
      image_pos = 'image_' + index + '_pos'

      if req.body[image_pos] is '1'
        req.body[image_pos] = ''

      image = "image" + req.body[image_pos]

      unless req.body[image_pos] is 'undefined' or req.body[image_pos] is undefined
        unless req.files[image].size is 0
          req.body[image] = req.files[image].name
        else 
          req.body[image] = req.body["prev_image" + req.body[image_pos]]
          if req.body['crop_' + index]
            convert_img(req.body[image], req.body['width_' + image], req.body['height_' + image], true, true, true)

    common_lib.syscall 'mkdir -p ' + filePath, ->
      unless req.files.image.size is 0
        save_img(req.files.image, req.body.crop_1, req.body.height_image, req.body.width_image)
      for idx in [2, 3, 4, 5, 6]
        unless req.files["image" + idx].size is 0
          save_img(req.files["image" + idx], req.body["crop_" + idx], req.body["height_image" + idx], req.body["width_image" + idx])

    
  app.post "/admin/blog/:id", staff, (req, res) ->
    process_save req
    delete req.body._id
    db.collection('blog').update {_id: req.params.id}, req.body, false, (err) ->
      if err then return res.send {success:false, error: err}
      res.redirect '/admin/blog'

  app.post "/admin/add-blog", staff, (req, res)->
    process_save req
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
