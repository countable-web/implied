var fs, middleware, path;

fs = require('fs');

path = require('path');

middleware = {
    page: function(req, res, next) {
        var pagename;
        if ((req.method || req.originalMethod) !== 'GET') {
            return next();
        }
        pagename = req.path.substring(1).replace(/\/$/, '');
        return fs.exists(path.join(req.app.get('dir'), 'views', 'pages', pagename + '.jade'), function(exists) {
            if (exists) {
                return res.render(path.join('pages', pagename), {
                    req: req
                });
            } else {
                return next();
            }
        });
    },

    /*
     * CMS
     */
    cms: function(req, res, next) {
        var db, pagename;
        db = req.app.get('db');
        if ((req.method || req.originalMethod) !== 'GET') {
            return next();
        }
        pagename = req.path.substring(1).replace(/\/$/, '');
        return db.collection('cms').findOne({
            page: pagename
        }, function(err, page) {
            if (page) {

                /*
                 * Override CMS.jade?
                 */
                return fs.exists(path.join(req.app.get('dir'), 'views', 'cms', pagename + '.jade'), function(exists) {
                    if (exists) {
                        return res.render(path.join('cms', pagename), page);
                    } else {
                        return res.render(path.join('cms', 'cms.jade'), page);
                    }
                });
            } else {
                return next();
            }
        });
    }
};

module.exports = function(app) {

    /*
     * if a cms table exists, use the cms middleware. FAILS, due to middleware order
    #app.get('db').getCollectionNames (err, names)->
     *  if err
     *    throw err
     *  if names.indexOf('cms') > -1
     */
    app.use(middleware.cms);

    /*
     * if a pages directory exists, use the pages middleware. FAILS, due to middleware order
    #fs.exists path.join((app.get 'dir'), 'views', 'pages'), (exists)->
     *  if exists
     *    app.use implied.middleware.page
     */
    app.use(middleware.page);
    app.use(app.router);
    return app.set('view options', {
        layout: false
    });
};
