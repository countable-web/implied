$ = require 'jquery'
fs = require 'fs'

module.exports = (opts)->
  
  common = require("./common") opts
  staff = common.staff

  app = opts.app
  db = opts.db
  
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
    obj_id = {_id: req.params.id}
    req.body.content = req.body.content.replace /\r\n/g, '<br>'
    if req.body.slug_field and req.body.slug_field.length
      req.body._id = req.body.slug_field

    if req.files.image and req.files.image.size > 0
      req.body.image = req.files.image.name
      fs.readFile req.files.image.path, (err, data) ->
        newPath = opts.upload_dir + "site/blog/" + req.files.image.name
        fs.writeFile newPath, data

    
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