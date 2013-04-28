# Express Mongo Users
md5 = require 'MD5'
uuid = require 'node-uuid'
fs = require 'fs'
async = require 'async'

blog = require './blog'
videos = require './videos'
blog = require './blog'
users = require './users'

admin = require './admin'

module.exports.init = (opts)->
  if opts.videos
    videos opts

  if opts.blog
    blog opts

  if opts.users
    users opts

  if opts.admin
    admin opts

  if opts.blog
    blog opts



