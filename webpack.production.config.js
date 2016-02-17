module.exports = {
  entry: [
    __dirname + '/src/js/'
  ],
  output: {
    path: __dirname + '/public/',
    filename: 'bundle.js'
  },
  module: {
    loaders: [
      { test: /\.js$/, exclude: /node_modules/, loaders: ['babel']},
      { test: /\.scss$/, loader: 'style!css'}
    ]
  }
};
