$ = require 'jquery'
fs = require 'fs'
async = require 'async'

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
    db.collection('blog').find({public_visible: 'on'}, {title:1, image:1, edit_1:1}).sort({pub_date : -1}).limit(NUM_PREVIEWS).toArray (err, blog_teasers) ->
      db.collection('blog').find(filter, {title:1, image:1, pub_date:1, teaser:1, edit_1:1}).sort({pub_date : -1}).skip(PAGE_SIZE*(pagenum-1)).limit(PAGE_SIZE+1).toArray (err, blog_articles) ->
        console.log "These are my blog articles: ",  blog_articles[0]
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
    filePath = opts.upload_dir + "site/blog/"
    entry = req.body

    save_img = (args, callback)->
      console.log "We are saving image: ", args.img_width
      newPath = filePath + args.img.name
      fs.readFile args.img.path, (err, data) ->
        fs.writeFile newPath, data, (err)->
          if args.crop
            convert_img { name: args.img.name, img_width: args.img_width, img_height: args.img_height, crop: true, resize: true, orient: true, effect: args.effect }, callback
          else
            convert_img { name: args.img.name, img_width: args.img_width, img_height: args.img_height, crop: false, resize: true, orient: true, effect: args.effect }, callback

    convert_img = (args, callback)->
      console.log "We are converting image: ", args.name
      if args.name is '' or args.name is undefined or args.name is 'undefined'
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

      stain_glass_effect = (filename)->
        return " ./bin/stainedglass -b 150 -t 0 " + filename + " " + filename
      
      enhanced_color_toning_effect = (filename)->
        return " ./bin/colortoning -o 'h,l,a' "  + filename + " " + filename + "; ./bin/enhancelab "  + filename + " " + filename

      screen_coloration_effect = (filename)->
        return " ./bin/screeneffects -s 6 " + filename + " " + filename + "; ./bin/coloration "  + filename + " " + filename

      turn_effect = (filename)->
        return " ./bin/turn "  + filename + " " + filename

      filmgrain_effect = (filename)->
        return " ./bin/filmgrain "  + filename + " " + filename

      enrich_retinex_effect = (filename)->
        return " ./bin/retinex -m HSL -f 50 -c 1.2 "  + filename + " " + filename + "; ./bin/enrich " + filename + " " + filename

      thumbPath = filePath + 'thumb-' + args.name
      newPath = filePath + args.name
      convert_commands = ''
      size = [args.img_width, args.img_height]

      if args.crop
        size = crop_img_dim(size[0], size[1])
        convert_commands += ' -gravity center -crop ' + size[0] + 'x' + size[1] + '+0+0 '

      if args.resize
        convert_commands += scale_img_dim()

      if args.orient
        convert_commands += auto_orient()

      newPath = '"' + newPath + '"'
      thumbPath = '"' + thumbPath + '"'
      full_command = 'convert ' + newPath + convert_commands + thumbPath
      full_command += '; '

      console.log "This is my effect: ", args.effect
      switch args.effect
        when 'stain_glass' then full_command += stain_glass_effect(thumbPath)
        when 'enhanced_color_toning' then full_command += enhanced_color_toning_effect(thumbPath)
        when 'screen_coloration' then full_command += screen_coloration_effect(thumbPath)
        when 'turn_effect' then full_command += turn_effect(thumbPath)
        when 'filmgrain_effect' then full_command += filmgrain_effect(thumbPath)
        when 'enrich_retinex' then full_command += enrich_retinex_effect(thumbPath)

      unless args.effect is 'none'
        full_command += ';'
      
      require('child_process').exec full_command, (error, stdout, stderr) ->
        console.log "Executing: ", full_command
        console.log "stdout: " + stdout
        #console.log "stderr: " + stderr  if stderr isnt null
        console.log "exec error: " + error  if error isnt null
        if error or stderr
          callback null, false
        else
          callback null, true

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
          console.log "This is my entry: ", entry[pos]
          if req.body['edit_' + idx]
            console.log "This is my image: ", entry[img]
            if entry[img]
              convert_task_arr.push {name: entry[img], img_width: entry['width_' + img], img_height: entry['height_' + img], crop: entry['crop_' + idx], resize: true, orient: true, effect: entry["effects_" + idx]}
      idx = idx + 1

    common_lib.syscall 'mkdir -p ' + filePath, ->
      idx = 1
      for img in ["", "2", "3", "4", "5", "6"]
        unless req.files["image" + img].size is 0
          save_task_arr.push {img: req.files["image" + img], crop: req.body["crop_" + idx], img_height: req.body["height_image" + img], img_width: req.body["width_image" + img], resize: true, orient: true, effect: req.body['effects_' + idx]}
        idx = idx + 1

      console.log "this is my save_task_arr: ", save_task_arr
      console.log "this is my convert_task_arr: ", convert_task_arr

      async.concatSeries save_task_arr, save_img, (err, results)->
        if err then console.log "We have an Error with saving: ", err else console.log "We've completed saving successfully! ", results
        async.concatSeries convert_task_arr, convert_img, (err, results)->
          if err then console.log "We have an Error with converting: ", err else console.log "We've completed converting successfully! ", results
          callback()

  app.post "/admin/blog/:id", staff, (req, res) ->
    process_save req, ()->
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
