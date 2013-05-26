
window.onerror = (message, url, linenumber)->
  $.get('/client_error',
    message:message
    url:url
    linenumber:linenumber
    user:window.onerror_user
    location: window.location + ''
  ).done (rsp)->
    console?.log rsp