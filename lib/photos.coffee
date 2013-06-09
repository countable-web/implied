
# Image conversion utilities.
# @param opts.resize {bool} resize the image if true.
module.exports.convert_img = (opts, callback)->
  if opts.name is '' or opts.name is undefined or opts.name is 'undefined'
    return true
  crop_img_dim = (w, h)->
    ratio = 1.31645569620253
    width = 0
    height = 0
    if w / h < ratio
      width = Math.round w
      height = Math.round w / ratio
    else
      height = Math.round h
      width = Math.round h * ratio
    return [width, height]

  scale_img_dim = ()->
    maxW = opts.img_width or 800
    maxH = opts.img_height or 500
    return " -resize '" + maxW + 'x' + maxH + "' "

  auto_orient = ()->
    return " -auto-orient "

  stain_glass_effect = (filename)->
    return " ./bin/stainedglass -b 150 -t 0 " + filename + " " + filename
  
  enhanced_color_toning_effect = (filename)->
    return " ./bin/colortoning -o 'h,l,a' "  + filename + " " + filename + "; ./bin/enhancelab "  + filename + " " + filename

  screen_coloration_effect = (filename)->
    return " ./bin/screeneffects -s 6 " + filename + " " + filename + "; ./bin/coloration "  + filename + " " + filename

  turn_effect = (filename)->
    return " ./bin/turn -a 10 "  + filename + " " + filename

  filmgrain_effect = (filename)->
    return " ./bin/filmgrain "  + filename + " " + filename

  enrich_retinex_effect = (filename)->
    return " ./bin/retinex -m HSL -f 50 -c 1.2 "  + filename + " " + filename + "; ./bin/enrich " + filename + " " + filename

  thumbPath = opts.filePath + 'thumb-' + opts.name
  newPath = opts.filePath + opts.name
  convert_commands = ''

  if opts.crop
    size = crop_img_dim(opts.img_width, opts.img_height)
    convert_commands += ' -gravity center -crop ' + size[0] + 'x' + size[1] + '+0+0 '

  if opts.resize
    convert_commands += scale_img_dim()

  if opts.orient
    convert_commands += auto_orient()

  newPath = '"' + newPath + '"'
  thumbPath = '"' + thumbPath + '"'
  full_command = 'convert ' + newPath + convert_commands + thumbPath
  full_command += '; '

  switch opts.effect
    when 'stain_glass' then full_command += stain_glass_effect(thumbPath)
    when 'enhanced_color_toning' then full_command += enhanced_color_toning_effect(thumbPath)
    when 'screen_coloration' then full_command += screen_coloration_effect(thumbPath)
    when 'turn_effect' then full_command += turn_effect(thumbPath)
    when 'filmgrain_effect' then full_command += filmgrain_effect(thumbPath)
    when 'enrich_retinex' then full_command += enrich_retinex_effect(thumbPath)

  unless opts.effect is 'none'
    full_command += ';'
  
  require('child_process').exec full_command, (error, stdout, stderr) ->
    console.log "Executing: ", full_command
    console.log "stdout: " + stdout
    console.log "exec error: " + error  if error isnt null
    if error or stderr
      callback null, false
    else
      callback null, true
