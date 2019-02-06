const testConfig = require('./test-config');

module.exports = function(app) {
  app.set('debug', true);
  app.set('host', testConfig.server.host);
  app.set('port', testConfig.server.port);
  app.set('db_name', testConfig.mongoUrl);
};

