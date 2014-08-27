implied
=======

Reusable webapp parts for Express with MongoDB.

Usage:

```javascript

var implied = require('implied');

implied(app); // initialize the library.

app.plugin('mongo', 'boilerplate', 'sendgrid', 'users'); // choose plugins you want in dependency order. Currently many things depend on 'mongo'.

```

### Mongo

The 'mongo' module wraps mongojs (a mongodb client), and sets an app variable with the database reference for use by other modules.

```javascript

app.plugin('mongo');
app.get('db').collection('mycollection').find({}).toArray(function(items){
  console.log(items);
});

```

### Boilerplate

A reasonable set of defaults for express middleware, for a typical website, so you can usually ignore that stuff. If you do need extra middleware in between the default middleware (ordinally), you won't be able to use this.

```javascript

app.plugin('boilerplate');

```

### Users

The 'users' module handles user registration, logins and password resets. Users are stored in MongoDB so this depends on the 'mongo' module.

```javascript
app.plugin('mongo', 'boilerplate', 'users'); // to install
```

### Sendgrid

Provides other modules with a wrapped sendgrid email client, app.get('mailer').

```javascript

app.plugin('sendgrid');
app.get('mailer').send_mail({to:'test@example.com', subject:'Test', body:'You are reading the contents of a test email... Bored?''});

```