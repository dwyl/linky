var jsdom = require('jsdom');
var fs    = require('fs');
var path  = require('path');

var doc = jsdom.jsdom(
  fs.readFileSync(path.resolve(__dirname, '../../../public/index.html'), 'utf8'),
  { url: 'http://localhost/public' }
);

var win = doc.defaultView;

global.document = doc;
global.window   = win;

Object.keys(win).forEach( function(key) {
  if (!(key in global)) {
    global[key] = win[key];
  }
});
