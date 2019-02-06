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
        let page_path = path.join(req.app.get('dir'), 'views', 'pages', pagename + '.' + (req.app.get('view engine') || 'jade'))
        fs.exists(page_path, function(page_exists) {
            if (page_exists) {
                return res.render(path.join('pages', pagename), {
                    req: req
                });
            } else {
                //Try loading default implied views as a fallback
                let fallback_page_path = path.join(__dirname, '../', 'views', pagename + '.' + (req.app.get('view engine') || 'jade'))
                fs.exists(fallback_page_path, function(fallback_exists) {
                    if(fallback_exists){
                        return res.render(path.join(pagename), {
                            req: req
                        });
                    }
                    return next();
                });
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
                return fs.exists(path.join(req.app.get('dir'), 'views', 'cms', pagename + '.' + req.app.get('view engine') || 'jade'), function(exists) {
                    if (exists) {
                        return res.render(path.join('cms', pagename), page);
                    } else {
                        return res.render(path.join('cms', 'cms'), page);
                    }
                });
            } else {
                return next();
            }
        });
    }
};

module.exports = function(app) {

    app.use(middleware.cms);
    app.use(middleware.page);
    app.use(app.router);
    app.set('view options', {
        layout: false
    });
};
