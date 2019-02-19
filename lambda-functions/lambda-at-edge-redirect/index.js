'use strict';

exports.handler = (event, context, callback) => {
console.log('Event: ', JSON.stringify(event, null, 2));
console.log('Context: ', JSON.stringify(context, null, 2));
var request = event.Records[0].cf.request;

var requestUrl = request.uri;

var redirectUrl = requestUrl.replace(/.html/gi, '');



console.log(redirectUrl);

request.uri = redirectUrl;

return callback(null, request);
};
