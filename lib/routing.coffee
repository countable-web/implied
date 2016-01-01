

middleware =

  page: (req, res, next)->
    unless (req.method or req.originalMethod) is 'GET'
      return next()

    pagename = req.path.substring(1).replace /\/$/, ''

    fs.exists path.join(req.app.get('dir'), 'views', 'pages', pagename+'.jade'), (exists)->
      if exists
        res.render path.join('pages', pagename),
          req: req
      else
        next()

  # CMS
  cms: (req, res, next)->

    db = req.app.get 'db'

    unless (req.method or req.originalMethod) is 'GET'
      return next()

    pagename = req.path.substring(1).replace /\/$/, ''

    db.collection('cms').findOne {page: pagename}, (err, page)->
      if page
        # Override CMS.jade?
        fs.exists path.join(req.app.get('dir'), 'views', 'cms', pagename+'.jade'), (exists)->
          if exists
            res.render path.join('cms', pagename), page
          else
            res.render path.join('cms', 'cms.jade'), page
      else
        next()


module.exports = (app)->
  # if a cms table exists, use the cms middleware. FAILS, due to middleware order
  #app.get('db').getCollectionNames (err, names)->
  #  if err
  #    throw err
  #  if names.indexOf('cms') > -1
  app.use middleware.cms
  
  # if a pages directory exists, use the pages middleware. FAILS, due to middleware order
  #fs.exists path.join((app.get 'dir'), 'views', 'pages'), (exists)->
  #  if exists
  #    app.use implied.middleware.page
  app.use middleware.page
  
  app.use app.router

  app.set('view options', { layout: false })
