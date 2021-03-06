var Mailer, base, util,
    extend = function(child, parent) {
        for (var key in parent) {
            if (hasProp.call(parent, key)) child[key] = parent[key];
        }

        function ctor() {
            this.constructor = child;
        }
        ctor.prototype = parent.prototype;
        child.prototype = new ctor();
        child.__super__ = parent.prototype;
        return child;
    },
    hasProp = {}.hasOwnProperty;

base = require('./base');

util = require('../../util');

Mailer = (function(superClass) {
    extend(Mailer, superClass);

    function Mailer(app) {
        Mailer.__super__.constructor.apply(this, arguments);
        this.sendgrid = require("sendgrid")(this.app.get('email_username'), this.app.get('email_password'));
    }


    /*
     * Send an email.
     *
     * @param opts.body {string}
     * @param opts.subject {string}
     * @param opts.from {string}
     * @param opts.to {array}
     */

    Mailer.prototype.send_mail = function(opts, callback) {
        var defaults, email, file, files, i, len;
        defaults = {
            from: this.default_from,
            fromname: this.default_from_name,
            text: opts.body,
            headers: {
                'X-SMTPAPI': '{"category": ' + (this.app.get('name')) + '}'
            }
        };
        files = opts.files || [];
        delete opts.files;
        email = new this.sendgrid.Email(util.extend({}, defaults, opts));
        for (i = 0, len = files.length; i < len; i++) {
            file = files[i];
            email.addFile(file);
        }
        return this.sendgrid.send(email, function(success, message) {
            var err;
            if (!success) {
                console.error(message);
            }
            err = null;
            if (!success) {
                err = message;
            }
            return typeof callback === "function" ? callback(err) : void 0;
        });
    };

    return Mailer;

})(base.Mailer);

module.exports = function(app) {
    return app.set('mailer', new Mailer(app));
};
