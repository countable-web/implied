var clear, path, util,
    hasProp = {}.hasOwnProperty;

util = require('../util');

path = require('path');

clear = function(val) {
    var type;
    type = typeof val;
    if (type === 'number') {
        return 0;
    } else {
        return '';
    }
};

module.exports = function(app, opts) {
    var db, forms, staff, template_base;
    if (opts == null) {
        opts = {};
    }
    if (opts.login_url == null) {
        opts.login_url = "/login";
    }
    db = app.get('db');
    forms = opts.forms || {};
    staff = app.get('plugins').users.staff;
    if (!staff) {
        throw "Admin requires the user module be installed.";
    }
    template_base = path.join(__dirname, "..", "views");

    /*
     * List of all collections.
     */
    app.get("/mongo-admin", staff, function(req, res) {
        return db.collectionNames(function(err, collections) {
            return res.render(path.join(template_base, "admin"), {
                collections: collections
            });
        });
    });

    /*
     * List of objects in collections
     */
    app.get("/mongo-admin/:collection", staff, function(req, res) {
        return db.collection(req.params.collection).find().toArray(function(err, records) {
            return res.render(path.join(template_base, "admin-list"), {
                title: req.params.collection,
                form: forms[req.params.collection],
                records: records
            });
        });
    });

    /*
     * New object
     */
    app.get("/mongo-admin/:collection/add", staff, function(req, res) {
        return db.collection(req.params.collection).findOne(function(err, rec) {
            var k, v;
            for (k in rec) {
                if (!hasProp.call(rec, k)) continue;
                v = rec[k];
                rec[k] = clear(v);
            }
            return res.render(path.join(template_base, "admin-object"), {
                title: req.params.collection,
                form: forms[req.params.collection],
                rec: rec
            });
        });
    });

    /*
     * Show / Edit an object
     */
    app.get("/mongo-admin/:collection/:id", staff, function(req, res) {
        return db.collection(req.params.collection).findOne({
            _id: util.oid(req.params.id)
        }, function(err, rec) {
            return res.render(path.join(template_base, "admin-object"), {
                title: req.params.collection,
                form: forms[req.params.collection],
                rec: rec
            });
        });
    });

    /*
     * Delete an object
     */
    app.get("/mongo-admin/:collection/:id/del", staff, function(req, res) {
        return db.collection(req.params.collection).remove({
            _id: util.oid(req.params.id)
        }, function(err, rec) {
            return res.redirect('/mongo-admin/' + req.params.collection);
        });
    });

    /*
     * Save an object
     */
    app.post("/mongo-admin/:collection/:id", staff, function(req, res) {
        if (req.params.id === 'add') {
            return db.collection(req.params.collection).insert(req.body, function(err) {
                return res.redirect('/mongo-admin/' + req.params.collection);
            });
        } else {
            return db.collection(req.params.collection).update({
                _id: util.oid(req.params.id)
            }, {
                $set: req.body
            }, function(err) {
                return res.redirect('/mongo-admin/' + req.params.collection);
            });
        }
    });
    return app.post("/mongo-admin/api/:collection/:id", staff, function(req, res) {
        return db.collection(req.params.collection).update({
            _id: new ObjectId(req.params.id)
        }, {
            $set: req.body
        }, function(err) {
            return res.send({
                message: err,
                success: !err
            });
        });
    });
};
