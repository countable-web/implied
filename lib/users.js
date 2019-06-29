var events, md5, me, util, request,
    hasProp = {}.hasOwnProperty;

request = require('request');

md5 = require('MD5');
const bcrypt = require('bcrypt');
const saltRounds = 10;

events = require('events');

util = require('../util');

me = module.exports = function (app, opts) {
    opts = opts || {};
    var Users, build_lookup_query, db, flash, goto_error, goto_then, login_url, mailer, ref, salt, server_path;
    salt = (ref = app.get('secret')) != null ? ref : 'secret-the-cat';
    if (!app.get('welcome_email')) {
        app.set('welcome_email', "Thanks for signing up for " + app.get("app_name"));
    }
    db = app.get('db');
    mailer = app.get('mailer');
    Users = db.collection('users');
    login_url = "/login";
    app.use(function (req, res, next) {
        if (req.session.email) {
            db.collection('users').find({
                email: req.session.email
            }, function (err, users) {
                if (err) throw err;
                if (users.length !== 1) throw new Error(req.session.email + ' matched ' + users.length);
                user = users[0]
                req.session.user = user
                req.session.user._id = user._id.toString();
                if (req.session.user.group_id) {
                    req.session.user.group_id = user.group_id.toString();
                }

                next();
            });
        } else {
            next();
        }
    });
    me.staff = function (req, res, next) {
        if (req.session.email) {
            return db.collection('users').findOne({
                email: req.session.email,
                admin: true
            }, function (err, user) {
                if (user) {
                    return next();
                } else {
                    flash(req, 'error', 'Not authorized.');
                    return res.redirect(login_url + "?then=" + req.path);
                }
            });
        } else {
            flash(req, 'error', 'Not authorized.');
            return res.redirect(login_url + "?then=" + req.path);
        }
    };
    flash = (require('../util')).flash;
    goto_then = function (req, res) {
        var redirect_path = req.query._then
            || req.body._then
            || req.query.then
            || req.body.then
            || '/';
        var new_url = server_path(req) + redirect_path
        return res.redirect(new_url);
    };
    goto_error = function (req, res) {
        return res.redirect(req.query.onerror || req.body.onerror || req.originalUrl);
    };
    me.login_success = function (req, user) {
        req.session.email = user.email || "no email";
        req.session.admin = user.admin;
        req.session.user = user;
        req.session.user._id = user._id.toString();
        if (req.session.user.group_id) {
            req.session.user.group_id = user.group_id.toString();
        }
        return req.session.cookie.maxAge = 14 * 24 * 60 * 60 * 1000;
    };
    build_lookup_query = function (params) {
        var q;
        q = {
            $or: []
        };
        if (typeof params.username === 'string') {
            q.$or.push({
                username: params.username.replace(/\s/g, "").toLowerCase()
            });
            q.$or.push({
                email: params.username.replace(/\s/g, "").toLowerCase()
            });
        }
        if (typeof params.email === 'string') {
            q.$or.push({
                username: params.email.replace(/\s/g, "").toLowerCase()
            });
            q.$or.push({
                email: params.email.replace(/\s/g, "").toLowerCase()
            });
        }
        return q;
    };

    const invalidResponse = function (callback, message) {
        return callback({
            success: false,
            message: message
        });
    }

    const validLoginResponse = function (callback, user, req) {
        if (!user.confirmed && app.get('email_confirm')) {
            return invalidResponse('Please confirm your email address before logging in.');
        } else {
            me.login_success(req, user);
            return callback({
                success: true,
                user: user,
                then: req.query._then
                    || req.body._then
                    || req.query.then
                    || req.body.then
                    || '/',
                message: 'You have been logged in.'
            });
        }
    };

    me.login = function (req, callback) {
        var lookup_query, plaintextPassword, query;
        lookup_query = build_lookup_query({
            username: req.param('username'),
            email: req.param('email')
        });
        plaintextPassword = req.param('password');
        if (!plaintextPassword) {
            return invalidResponse(callback, 'Please provide a password');
        }

        db.collection('users').findOne(lookup_query, function (err, user) {
            if (err) {
                return invalidResponse(callback, 'Internal Server Error');
            }

            if (user) {

                if (user.resetrequired) {
                    return invalidResponse(callback, 'Please reset your password.');
                }
                //Check New Hash
                bcrypt.compare(plaintextPassword, user.password, function (err, isMatch) {
                    if (isMatch) {
                        return validLoginResponse(callback, user, req);
                    }
                    //Check against old hash
                    else if (user.password === md5(plaintextPassword + salt)) {
                        bcrypt.hash(plaintextPassword, saltRounds, function (err, hash) {
                            if (err || !hash) {
                                return invalidResponse(callback, 'Internal Server Error');
                            }

                            let update_query = {
                                $set: {
                                    password: hash
                                }
                            };

                            if (hash) {
                                db.collection('users').findAndModify({ query: lookup_query, update: update_query, new: true }, function (err, user) {
                                    if (err || !user) {
                                        return invalidResponse(callback, 'Internal Server Error');
                                    }
                                    return validLoginResponse(callback, user, req);
                                });
                            }

                        });
                    }
                });
            } else {
                return invalidResponse(callback, 'Email or password incorrect.');
            }
        });
    };

    me.signup = function (req, callback) {
        var complete, k, ref1, ref2, user, v, validator;
        user = {};
        ref1 = req.query;
        for (k in ref1) {
            if (!hasProp.call(ref1, k)) continue;
            v = ref1[k];
            if (k.substr(0, 1) !== '_') {
                user[k] = me.sanitize(v, k);
            }
        }
        ref2 = req.body;
        for (k in ref2) {
            if (!hasProp.call(ref2, k)) continue;
            v = ref2[k];
            if (k.substr(0, 1) !== '_') {
                user[k] = me.sanitize(v, k);
            }
        }
        user.email = user.email.replace(" ", "").toLowerCase();
        user.confirmed = false;
        user.email_confirmation_token = Math.random();
        user.password = user.password || '';
        if (!user.email) {
            return invalidResponse(callback, "Please enter an email address.");
        }

        bcrypt.hash(user.password, saltRounds, function (err, hash) {
            if (err || !hash) {
                return invalidResponse('Internal Server Error');
            }

            user.password = hash;
            if (!/^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/.test(user.email)) {
                return invalidResponse(callback, "Invalid email address.");
            }
            complete = function (errs) {
                var lookup;
                if (errs && errs.length) {
                    return invalidResponse(callback, "Internal Server Error");
                }
                lookup = build_lookup_query(user);
                return Users.find(lookup).toArray(function (err, users) {
                    if (err) {
                        throw err;
                    }
                    if (users.length === 0 || users[0].pending) {
                        return Users.update(lookup, user, {
                            upsert: true
                        }, function (err, result) {
                            return Users.findOne({
                                email: user.email
                            }, function (err, user) {
                                if (err) {
                                    return invalidResponse(callback, "Internal Server Error");
                                }
                                if (mailer != null) {
                                    mailer.send_mail({
                                        to: user.email,
                                        subject: app.get("welcome_email_subject") || "Welcome!",
                                        body: util.format(app.get("welcome_email"), {
                                            first_name: user.first_name || user.email,
                                            confirm_link: "http://" + (app.get('host')) + "/confirm-email?token=" + user.email_confirmation_token
                                        })
                                    });
                                }
                                me.emitter.emit('signup', user);
                                if (app.get('email_confirm')) {
                                    return callback({
                                        success: true,
                                        message: 'Thanks for signing up! Please follow the instructions in your welcome email.'
                                    });
                                } else {
                                    me.login_success(req, user);
                                    return callback({
                                        success: true,
                                        user: user,
                                        message: 'Thanks for signing up!'
                                    });
                                }
                            });
                        });
                    } else {
                        return invalidResponse(callback, "User already exists with that email");
                    }
                });
            };
            validator = app.get('user_signup_validator');
            if (validator) {
                return validator(req, complete);
            } else {
                return complete(null);
            }
        });
    };
    me.logout = function (req) {
        req.session.email = null;
        req.session.admin = null;
        return req.session.user = null;
    };
    app.post("/login", function (req, res) {
        return me.login(req, function (result) {
            if (result.success) {
                flash(req, "success", result.message);
                return goto_then(req, res);
            } else {
                flash(req, "error", result.message);
                return goto_error(req, res);
            }
        });
    });
    app.get("/logout", function (req, res) {
        if (opts.logoutSSO_Discourse) {
            request.post(opts.logoutSSO_Discourse + req.session.user._id + '/log_out');
        }
        me.logout(req);
        flash(req, "success", "You've been safely logged out");
        return goto_then(req, res);
    });
    app.get("/logout.json", function (req, res) {
        me.logout(req);
        return res.send({
            success: true
        });
    });
    app.post("/signup", function (req, res) {
        return me.signup(req, function (result) {
            if (result.success) {
                flash(req, "success", result.message);
                return goto_then(req, res);
            } else {
                flash(req, "error", result.message);
                return goto_error(req, res);
            }
        });
    });
    app.get("/login.json", function (req, res) {
        return me.login(req, function (result) {
            return res.send(result);
        });
    });
    app.get("/signup.json", function (req, res) {
        return me.signup(req, function (result) {
            return res.send(result);
        });
    });
    server_path = function (req) {
        var url;
        url = req.protocol + "://" + req.host;
        if (app.get('port') && app.get('port') !== 80) {
            url += ":" + app.get('port');
        }
        return url;
    };
    app.get("/confirm-email", function (req, res) {

        // No token exists
        if (!req.query.token) {
            flash(req, 'error', 'No confirmation token provided');
            return goto_error(req, res);
        }

        // Token should be a valid number
        const token = parseFloat(req.query.token);
        if (isNaN(token)) {
            flash(req, 'error', 'Invalid confirmation token');
            return goto_error(req, res);
        }

        const query = {
            email_confirmation_token: token
        };

        Users.update(query, {
            $set: {
                confirmed: true
            }
        }, function (err) {
            if (err) {
                flash(req, 'error', 'Email confirmation failed');
                return goto_error(req, res);
            }
            Users.findOne(query, function (err, user) {
                if (err) {
                    throw err;
                }

                if (!user) {
                    flash(req, 'error', 'Error: User does not exist!');
                    return goto_error(req, res);
                }

                me.login_success(req, user);
                if (user) {
                    flash(req, 'success', 'Email confirmed');
                }
                return goto_then(req, res);
            });
        });
    });
    app.post("/reset-password-submit", function (req, res) {
        return Users.findOne({
            email: req.body.email
        }, function (err, user) {
            if (user) {
                let token = "" + Math.random();
                Users.update({
                    _id: util.oid(user._id)
                }, {
                        $set: {
                            password_reset_token: token
                        }
                    });
                if (mailer != null) {
                    mailer.send_mail({
                        to: user.email,
                        subject: "Password Reset",
                        body: "Go here to reset your password: http://" + (app.get('host')) + "/reset-password-confirm?token=" + token
                    }, function (err) {
                        if (err) {
                            throw err;
                        }
                    });
                }
                flash(req, "success", "You've been sent an email with instructions on resetting your password.");
                return goto_then(req, res);
            } else {
                flash(req, "error", "No user with that email address was found.");
                return res.render('pages/reset-password-submit');
            }
        });
    });
    app.post("/reset-password-confirm", function (req, res) {
        let query;
        if (req.session.email) {
            query = {
                email: req.session.email
            };
        } else {
            query = {
                password_reset_token: req.query.token
            };
        }
        return Users.findOne(query, function (err, user) {
            if (err) {
                flash(req, 'error', 'Password reset failed');
                return goto_then(req, res);
            }

            if (user) {
                let new_token = "" + Math.random();

                bcrypt.hash(req.body.password, saltRounds, function (err, hash) {
                    return Users.update(query, {
                        $set: {
                            resetrequired: false,
                            password: hash,
                            password_reset_token: new_token
                        }
                    }, function (err) {
                        if (err) {
                            flash(req, 'error', 'Password reset failed');
                            return goto_error(req, res);
                        }
                        flash(req, 'success', 'Password was reset');
                        return goto_then(req, res);
                    });
                });
            } else {
                flash(req, 'error', 'Invalid password reset link');
                return goto_error(req, res);
            }
        });
    });
    app.get("/become-user/:id", me.staff, function (req, res) {
        return Users.findOne({
            _id: util.oid(req.params.id)
        }, function (err, user) {
            if (err) {
                throw err;
            }
            me.login_success(req, user);
            return goto_then(req, res);
        });
    });
};

me.emitter = new events.EventEmitter();

me.restrict = function (req, res, next) {
    if (req.session.email) {
        return next();
    } else {
        return res.redirect("/login" + "?then=" + req.path);
    }
};

me.restrict_rest = function (req, res, next) {
    if (req.session.email) {
        return next();
    } else {
        return res.send({
            success: false,
            message: 'Not authenticated.'
        });
    }
};

me.sanitize = function (s, field_name) {
    var error;
    if (field_name && field_name.substr(field_name.length - 3) === "_id") {
        try {
            return util.oid(s);
        } catch (error1) {
            error = error1;
            return console.error('bad id string:', s, error);
        }
    } else {
        return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;');
    }
};
