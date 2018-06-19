/*
 * Image conversion utilities.
 * @param opts.resize {bool} resize the image if true.
 */
module.exports.convert_img = function(opts, callback) {
    var auto_orient, convert_commands, crop_img_dim, enhanced_color_toning_effect, enrich_retinex_effect, filmgrain_effect, full_command, newPath, scale_img_dim, screen_coloration_effect, size,
        stain_glass_effect, thumbPath, turn_effect;
    if (opts.name === '' || opts.name === void 0 || opts.name === 'undefined') {
        return true;
    }
    crop_img_dim = function(w, h) {
        var height, ratio, width;
        ratio = 1.31645569620253;
        width = 0;
        height = 0;
        if (w / h < ratio) {
            width = Math.round(w);
            height = Math.round(w / ratio);
        } else {
            height = Math.round(h);
            width = Math.round(h * ratio);
        }
        return [width, height];
    };
    scale_img_dim = function() {
        var maxH, maxW;
        maxW = opts.img_width || 800;
        maxH = opts.img_height || 500;
        return " -resize '" + maxW + 'x' + maxH + "' ";
    };
    auto_orient = function() {
        return " -auto-orient ";
    };
    stain_glass_effect = function(filename) {
        return " ./bin/stainedglass -b 150 -t 0 " + filename + " " + filename;
    };
    enhanced_color_toning_effect = function(filename) {
        return " ./bin/colortoning -o 'h,l,a' " + filename + " " + filename + "; ./bin/enhancelab " + filename + " " + filename;
    };
    screen_coloration_effect = function(filename) {
        return " ./bin/screeneffects -s 6 " + filename + " " + filename + "; ./bin/coloration " + filename + " " + filename;
    };
    turn_effect = function(filename) {
        return " ./bin/turn -a 10 " + filename + " " + filename;
    };
    filmgrain_effect = function(filename) {
        return " ./bin/filmgrain " + filename + " " + filename;
    };
    enrich_retinex_effect = function(filename) {
        return " ./bin/retinex -m HSL -f 50 -c 1.2 " + filename + " " + filename + "; ./bin/enrich " + filename + " " + filename;
    };
    thumbPath = opts.filePath + 'thumb-' + opts.name;
    newPath = opts.filePath + opts.name;
    convert_commands = '';
    if (opts.crop) {
        size = crop_img_dim(opts.img_width, opts.img_height);
        convert_commands += ' -gravity center -crop ' + size[0] + 'x' + size[1] + '+0+0 ';
    }
    if (opts.resize) {
        convert_commands += scale_img_dim();
    }
    if (opts.orient) {
        convert_commands += auto_orient();
    }
    newPath = '"' + newPath + '"';
    thumbPath = '"' + thumbPath + '"';
    full_command = 'convert ' + newPath + convert_commands + thumbPath;
    full_command += '; ';
    switch (opts.effect) {
        case 'stain_glass':
            full_command += stain_glass_effect(thumbPath);
            break;
        case 'enhanced_color_toning':
            full_command += enhanced_color_toning_effect(thumbPath);
            break;
        case 'screen_coloration':
            full_command += screen_coloration_effect(thumbPath);
            break;
        case 'turn_effect':
            full_command += turn_effect(thumbPath);
            break;
        case 'filmgrain_effect':
            full_command += filmgrain_effect(thumbPath);
            break;
        case 'enrich_retinex':
            full_command += enrich_retinex_effect(thumbPath);
    }
    if (opts.effect !== 'none') {
        full_command += ';';
    }
    return require('child_process').exec(full_command, function(error, stdout, stderr) {
        console.log("Executing: ", full_command);
        console.log("stdout: " + stdout);
        if (error !== null) {
            console.log("exec error: " + error);
        }
        if (error || stderr) {
            return callback(null, false);
        } else {
            return callback(null, true);
        }
    });
};
