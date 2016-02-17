var WebpackOnBuildPlugin = require('on-build-webpack');
var child_process        = require('child_process');

module.exports = {
    entry: [__dirname + '/test/front/'],
    output: {
      path: __dirname + '/test/front/',
      filename: 'dev_test.bundle.js'
    },
    module: {
      loaders: [
        { test: /\.js$/, exclude: /node_modules/, loaders: ['babel']},
        { test: /\.css$/, loader: 'style!css'}
      ]
    },
    target: 'node',
    watch: true,
    plugins: [
      new WebpackOnBuildPlugin(function () {
        child_process.exec(
          'node -r ./test/front/integration/init_fake_dom.js test/front/dev_test.bundle.js',
          function (error, stdout) {
            console.log(stdout && 'stdout: ' + stdout);
            if (error !== null) {
              console.log(error && 'exec error:' + error);
            }
          }
        );
      })
    ]
};
