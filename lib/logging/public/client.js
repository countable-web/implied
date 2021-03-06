window.onerror = function(message, url, linenumber) {
    return $.get('/client_error', {
        message: message,
        url: url,
        linenumber: linenumber,
        user: window.onerror_user,
        location: window.location + ''
    }).done(function(rsp) {
        return typeof console !== "undefined" && console !== null ? console.log(rsp) : void 0;
    });
};
