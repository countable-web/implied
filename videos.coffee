$ = require 'jquery'
fs = require 'fs'
async = require 'async'

module.exports = (opts)->
  common = require("./common") opts
  photos = require './photos'
  staff = common.staff

  app = opts.app
  db = opts.db

  # process file data in request
  process_save = (req, callback)->

    # Save file data to local storage on server
    save_file = (args, callback)->
      newPath = filePath + args.file.name

      fs.readFile args.file.path, (err, data) ->
        fs.writeFile newPath, data, (err)->
          if args.type is 'image'
            photos.convert_img { filePath: filePath, name: args.file.name, crop: false, resize: true, orient: true, effect: args.effect }, callback
          else
            
            cmd = 'avconv -loglevel quiet -y -i "' + newPath + '" -s vga -b 800k -c:v libx264 -r 23.976 -acodec ac3 -ac 1 -ar 22050 -ab 64k "' + filePath + 'stream-' + args.file.name + '"'
            console.log "AVCONV COMMAND:", cmd
            # Don't wait for processing - it takes forever.
            common.syscall cmd, ->
              
            
            callback null, true

    entry = req.body
    obj_id = {_id: req.params.id}
    filePath = opts.upload_dir + "site/videos/" # File upload directory
    entry.content = entry.content.replace /\r\n/g, '<br>' # Modify content display properly in HTML
    save_task_arr = [] # Array to hold tasks to be saved

    common.syscall 'mkdir -p ' + filePath, ->
      # If user uploaded data, store tasks to process files in save_task_arr
      if req.files.image.size is 0
        entry.image = entry.prev_image
      else
        entry.image = req.files.image.name
        save_task_arr.push {filePath: filePath, file: req.files["image"], type: 'image', crop: false, resize: true, orient: true, effect: 'none'}

      if req.files.video.size is 0
        entry.video = entry.prev_video
      else
        entry.video = req.files.video.name
        save_task_arr.push {filePath: filePath, file: req.files["video"], type: 'video'}

      # If no data was uploaded by the user, set image and video to previous values.
      if save_task_arr.length is 0
        return callback()

      # We process the save file tasks asynchronously.
      #
      # concatSeries - Applies save_file to each item in save_task_arr, concatenating the boolean results. 
      # An OR operation is performed for each boolean result, finalizing in a single true or false.
      async.concatSeries save_task_arr, save_file, (err, results)->
        if err
          console.error err
          console.error "results were:", results
        return callback()

  # Get public videos filtered by keywords if query is provided.
  app.get "/videos", staff, (req,res) ->
    filter = $and: [
      public_visible: 'on'
    ,
      "keywords":
        $regex: req.query.search
        $options: "i"
    ]

    db.collection('videos').find(filter).sort({title : 1}).toArray (err, video_articles) ->
      res.render 'videos/video-entries',
        req: req
        email: req.session.email
        video_articles: video_articles
  
  add_video = (req, res) ->
    res.render "admin/video-add",
      req: req
      rec: {} 
      email: req.session.email
  
  app.get "/admin/add-video", staff, add_video

  app.post "/admin/add-video", staff, (req, res)->
    process_save req, ()->
    
      if not req.body.title
        common.flash 'Title is required.'
        add_video req, res
      else
        req.body._id = req.body.title.toLowerCase().replace(/\s/g, '-')

      db.collection('videos').findOne {_id: req.body._id}, (err, entry)->
        if entry
          common.flash 'Title is already used.'
          add_video req, res
        else
          db.collection("videos").insert req.body, (err, entry)->
            if err then console.error err
            res.redirect '/admin/videos'

  app.get "/admin/videos", staff, (req, res) ->
    db.collection('videos').find().sort({title: 1}).toArray (err, entries)->
      res.render "admin/video-list",
        req: req
        email: req.session.email
        entries: entries

  app.get "/admin/videos/:id", staff, (req, res) ->
    db.collection('videos').findOne {$or: [{_id: req.params.id}, {slug_field: req.params.id}]}, (err, rec) ->
      res.render "admin/video-add",
        title: req.params.collection
        req: req
        email: req.session.email
        rec: rec

  app.post "/admin/videos/:id", staff, (req, res) ->
    process_save req, ()->
      delete req.body._id
      db.collection('videos').update {_id: req.params.id}, req.body, false, (err) ->
        if err then return res.send {success:false, error: err}
        res.redirect '/admin/videos'

  app.get "/videos/:id", (req,res) ->
    db.collection('videos').findOne {$or: [{_id: req.params.id}, {slug_field: req.params.id}]}, (err, entry)->
      console.log err if err
      res.render "videos/video-entry",
        req: req
        email: req.session.email
        entry: entry

