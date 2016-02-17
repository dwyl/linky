'use strict';

import { compose, createStore, applyMiddleware } from 'redux';
import { syncHistory }                           from 'react-router-redux';
/* istanbul ignore next */
import createLogger                              from 'redux-logger';
// Required for replaying actions from devtools to work
// reduxRouterMiddleware.listenForReplays(store)

import history from './history.js';
import reducer from './reducers';


const reduxRouterMiddleware = syncHistory(history);
const createEnhancedStore   = compose(
  applyMiddleware(
    reduxRouterMiddleware,
    createLogger()
  )
)(createStore);

export default () => createEnhancedStore(reducer);
