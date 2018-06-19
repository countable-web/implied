var me, mongojs;

mongojs = require('mongojs');

me = module.exports = function(app) {
    var connect_string;
    if (!app.get('db_name')) {
        app.set('db_name', app.get('app_name'));
    }
    connect_string = app.get('db_name');

    var db = mongojs(connect_string, [], {
        authMechanism: 'ScramSHA1'
    });

    // add promise support.
    let _collection_proto = db.users.__proto__;
    let _cursor_proto = db.users.find({
        _id: 1
    }).__proto__;

    /**
     * Returns a promise to find and return an array
     * TODO: move this into implied or mongojs.
     */
    _collection_proto.idPromise = function(id) {
        var collection = this;
        var promise = new Promise(function(resolve, reject) {
            if (typeof id === 'string') id = implied.util.oid(id);
            collection.findOne({
                _id: id
            }, function(err, result) {
                if (err) {
                    throw new Error(err)
                }
                if (result) {
                    resolve(result)
                } else {
                    resolve(null)
                }
            });
        });
        return promise;
    };

    _cursor_proto.toArrayPromise = function() {
        var cursor = this;
        var promise = new Promise(function(resolve, reject) {
            cursor.toArray(function(err, results) {
                if (err) throw new Error(err)
                resolve(results)
            });
        });
        return promise;
    };
    _collection_proto.insertPromise = function(obj) {
        var collection = this;
        var promise = new Promise(function(resolve, reject) {
            collection.insert(obj, function(err, result) {
                if (err) {
                    throw new Error(err)
                }
                if (result) {
                    resolve(result)
                } else {
                    resolve(null)
                }
            });
        });
        return promise;
    };

    process.on('unhandledRejection', r => console.log(r));

    app.set('db', db);
};

me.oid_str = function(inp) {
    return (me.oid(inp)).toString();
};

me.oid = function(inp) {
    var byte, result;
    if (inp instanceof mongojs.ObjectId) {
        // if we already have an ObjectId, just return it back.
        return inp;
    } else if (inp.bytes) {
        // a Buffer like thing.
        result = ((function() {
            var i, len, ref, results;
            ref = inp.bytes;
            results = [];
            for (i = 0, len = ref.length; i < len; i++) {
                byte = ref[i];
                results.push(implied.util.zpad(byte.toString(16), 2));
            }
            return results;
        })()).join('');
        return mongojs.ObjectId(result);
    } else {
        // A plain old string
        return mongojs.ObjectId('' + inp);
    }
};
