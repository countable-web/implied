# implied

Ludicrously practical, reusable web app parts for Express with MongoDB. Acts as a convenience wrapper around express to reduce boilerplate cruft. Aims to provide an alternative to the MEAN stack without explicitly using angular, and certainly avoiding the use Mongoose, which forces a schema on a database (MongoDB) whose primary benefit is the lack of one. Implied is a work in progres but is used in several production websites.

Implied suggests you make modules callable, and take an express app as their first argument. Your app root needs a config.js in this format, at the very least.

config.js
````javascript
module.exports = function(app){
    app.set('port', 3000);
}
````

Here's what your app.js should look like for a minimal implied installation.

Usage:

```javascript

var implied = require('implied');

app = implied(); // initialize the library.

app.plugin('mongo', 'boilerplate', 'sendgrid', 'users'); // choose plugins you want in dependency order. Currently many things depend on 'mongo'.

```

### Mongo

The 'mongo' module wraps [mongojs](https://github.com/mafintosh/mongojs) (a mongodb client), and sets an app variable with the database reference for use by other modules.

```javascript

app.plugin('mongo');
app.get('db').collection('mycollection').find({}).toArray(function(items){
  console.log(items);
});

```

### Boilerplate

A reasonable set of defaults for express middleware, for a typical website. It includes bodyParser, cookies, sessions. If you do need extra middleware in between the default middleware (ordinally), you won't be able to use this.

```javascript

app.plugin('boilerplate');

```

### Users

The 'users' module handles user registration, logins and password resets. Users are stored in MongoDB so this depends on the 'mongo' module.

```javascript
app.plugin('mongo', 'boilerplate', 'users'); // to install
```

You'll need the following views with HTML forms, unless you'd rather use the rest interface.

views/pages/login.jade - contains a form with an input of name "password" and "email", at least.
views/pages/signup.jade - contains a form with an input of name "password" and "email", at least.
views/pages/password-reset-submit.jade - contain a form with an input of name "email".

### Hooks
You can trigger something to happen when a user signs up as follows:

```
implied.on('signup', function(user){});
```

### Sendgrid

Provides other modules with a wrapped sendgrid email client, app.get('mailer').

```javascript

app.plugin('sendgrid');
app.get('mailer').send_mail({to:'test@example.com', subject:'Test', body:'You are reading the contents of a test email... Bored?''});

```

### Contributing

Follow the basic design idea of being pragmatic please. New features should directly solve specific problems, and not introduce abstraction without doing so. And yes, implied is written in coffeescript. If you have a strong opinion about this... please just relax! The controversy over coffeescript is much more costly than the very minimal difference between using it and javascript :)


