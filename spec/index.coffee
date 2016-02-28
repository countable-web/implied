implied = require '..'
requests = require 'requests'


console.log('...')

describe 'Hello World App', ->
  console.log('...')
  describe 'setup app', ->
    console.log('...')
    it 'was set up', (done)->
      app = implied()
      console.log('...')
      console.log('test')
      implied.mongo app
      implied.sendgrid app
      implied.boilerplate app
      expect(app.db).not.toEqual(undefined)
      expect(1).toBe 1
      setTimeout ->
       done()
