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
    save_img = (img)->
      fs.readFile img.path, (err, data) ->
        newPath = filePath + img.name
        fs.writeFile newPath, data

    obj_id = {_id: req.params.id}
    req.body.content = req.body.content.replace /\r\n/g, '<br>'
    if req.body.slug_field and req.body.slug_field.length
      req.body._id = req.body.slug_field

    if req.body.image_1_pos is '1'
      req.body.image_1_pos = ''
    else if req.body.image_2_pos is '1'
      req.body.image_2_pos = ''
    else if req.body.image_3_pos is '1'
      req.body.image_3_pos = ''
    else if req.body.image_4_pos is '1'
      req.body.image_4_pos = ''
    else if req.body.image_5_pos is '1'
      req.body.image_5_pos = ''
    else if req.body.image_6_pos is '1'
      req.body.image_6_pos = ''

    console.log "these are my blog images ", req.body
    console.log "these are my files ", req.files

    unless req.body.image_1_pos is 'undefined'
      unless req.files.image.size is 0
        req.body["image" + req.body.image_1_pos] = req.files.image.name 
      else 
        console.log "Setting image 1 to: ", req.body.image
        req.body["image" + req.body.image_1_pos] = req.body.prev_image
    unless req.body.image_2_pos is 'undefined'
      unless req.files.image2.size is 0
        req.body["image" + req.body.image_2_pos] = req.files.image2.name
      else 
        req.body["image" + req.body.image_2_pos] = req.body.prev_image2
    unless req.body.image_3_pos is 'undefined'
      unless req.files.image3.size is 0
        req.body["image" + req.body.image_3_pos] = req.files.image3.name
      else 
        req.body["image" + req.body.image_3_pos] = req.body.prev_image3
    unless req.body.image_4_pos is 'undefined'
      unless req.files.image4.size is 0
        req.body["image" + req.body.image_4_pos] = req.files.image4.name
      else 
        req.body["image" + req.body.image_4_pos] = req.body.prev_image4
    unless req.body.image_5_pos is 'undefined'
      unless req.files.image5.size is 0
        req.body["image" + req.body.image_5_pos] = req.files.image5.name
      else 
        req.body["image" + req.body.image_5_pos] = req.body.prev_image5
    unless req.body.image_6_pos is 'undefined'
      unless req.files.image6.size is 0
        req.body["image" + req.body.image_6_pos] = req.files.image6.name
      else
        console.log "Setting image 6 to: ", req.body.image6
        req.body["image" + req.body.image_6_pos] = req.body.prev_image6

    filePath = opts.upload_dir + "site/blog/"
    common_lib.syscall 'mkdir -p ' + filePath, ->
      save_img(req.files.image)
      save_img(req.files.image2)
      save_img(req.files.image3)
      save_img(req.files.image4)
      save_img(req.files.image5)
      save_img(req.files.image6)

    
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