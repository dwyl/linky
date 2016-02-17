# setup
:lightning: A quick-start guide and template for setting up dwyl React - Redux - React-Router projects.

## Linting & Editors

[TODO] Decide on configuration!

### EditorConfig

[EditorConfig](http://editorconfig.org/) can be used to keep consistent styling across editors. The .editorconfig file is configurable and should be consistent with the eslint config below.

### ESLint

[Eslint](https://github.com/eslint/eslint) and [eslint-plugin-react](https://github.com/yannickcr/eslint-plugin-react) are used to lint files in the precommit hook.
The .eslintrc and .eslintignore files are configurable with these [rules](http://eslint.org/docs/rules/).

### Editor Specifics
We recommend using [ATOM](https://atom.io/).
##### ATOM
To take advantage of above please install the  [ESlint](https://atom.io/packages/linter-eslint) and [EditorConfig](https://github.com/sindresorhus/atom-editorconfig) packages. (if you see no change after enabling restart atom)

## Tools and Architecture (what, why, how)

### Tape
#### What
- Lightweight backend testing framework. Docs [here](https://github.com/substack/tape).

#### Why
- Simple.
- Fast.

#### How
- Run tests with basic assertions like `ok`, `equal` and `deepEqual`.

### Istanbul
#### What
- npm module that checks the code coverage of tests. Docs [here](https://github.com/gotwarlost/istanbul).

#### Why?
- So we know our tests cover 100% of our code!

#### How?
- We wrap babel in babel-istanbul which allows us to use istanbul while running our tests with babel node. This allows use to check the test coverage on our source code (ie without transpiling it to es5).
- Run our test scripts with babel-istanbul module. ie `babel-node babel-istanbul tape test/`.
- We do not incude our integration test in the tests we watch for coverage. This means our coverage must be completed with only our unit tests.

### Webpack
#### What?
- Build helper for React, css and ES6. Docs [here](https://webpack.github.io/docs/).

#### Why?
- Makes transpiling and bundling source code quick and easy.
- Continuously bundle code on change, refresh in browser while holding state.
- Watch changes to tests and bundle and run them to alert you if they ever break.

#### How?
- Configure Babel for build see below and use babel-loader in webpack config.
- Create `webpack.development.config.js` file and use [Webpack Dev Server](https://webpack.github.io/docs/webpack-dev-server.html) to create server which pushes changes into the browser (using react-hot-loader plugin).
- Create `webpack.test.config.js` file to quickly transpile tests and run test scripts whenever files change.

### Babel
#### What?
- Tool for transpiling into JS. Docs [here](https://babeljs.io/docs/setup/).

#### Why?
- Defacto into ES5 transpiler for react's JSX and ES6.

#### How?
- `.babelrc` file specifies what babel will transpile. We are including `es2015` for es6, `react` for JSX and `stage-0` for some bleeding edge ES7 features.
- We use babel as a loader in webpack, this means babel will transpile before webpack puts everything into our bundle.
- `babel-node` allows use to run untranspiled code. we use this to check our test's code coverage.

### React
#### What?
- Facebooks rendering library for create html views from data. Docs [here](https://facebook.github.io/react/docs/getting-started.html).

#### Why?
- Keeps view code code modular with components.
- This helps a lot with development of large codebase by many teams.
- Unidirectional data flow makes code very easy to reason about.
- Easy to integrate with Redux and other flux implementations.
- Easy to test components in isolation using shallow rendering.
- Efficient rendering with the virtual dom.
- Facebook must use it for some reason...

#### How?
- Use Webpack and Babel to transpile and bundle into something that will render client side.

### React Router
#### What?
- A module that lets us treat our one page app like a traditional site (the back button works!!). Docs [here](https://github.com/rackt/react-router).

#### Why?
- Mostly so that the back and forward buttons work. Allows us to nest component within each other at the top level of our app (rather than only specifying what a components children are inside that child).
- Have one place that stores the higher logic of the app.

#### How?
- Use a `Router` component with nested `Route` components that create a tree to relates urls to components.
- Make this `Router` component direct child of the `Provider`.

### React Router Redux
#### What?
- Module to sync up our window location with the redux state of our app.
- `react-router-redux` acts similarly to a reducer in that it has its own action-types etc.
- Docs [here](https://github.com/rackt/react-router).

#### Why?
- So that we can track navigation though the site.
- So that we can recreate the users views by looking at their saved redux state.

#### How?
- react-router-redux gives us a store enhancer, reducer, navigation actions and action types. These allow us to sync the url and back buttons with our app's routing state.
- **Warning**: It is a bad pattern to use react-redux's connect decorator to map the state from this reducer to props on your Route components. This can lead to infinite loops and performance problems. react-router already provides this for you via this.props.location

### React Test Utils And
#### What?
- Tools to to render components in isolation from others (shallow). Docs [here](https://facebook.github.io/react/docs/test-utils.html).

#### Why?
- We need to test our react components!

#### How?
- ShallowRender component and check the presence and layout of subcomponents within a component and make sure they have correct props, styles and children passed to them.
- This acts as a unit test of the component and will need further integration testing afterwards.

### Redux
### [What?, Why?, How? by DWYL](https://github.com/dwyl/learn-redux) :)
- to decrease boilerplate when creating reducers we have build a function to create reducers (`src/js/reducers/createReducer.js`), it is important to note that this reducer returns the state when no action is found for the specified action type. Ie in the default case state is returned).
