'use strict';

import { routeReducer } from 'react-router-redux';
import { combineReducers } from 'redux';

import template from './template.js';

const rootReducer = combineReducers({
  template,
  routeReducer
});

export default rootReducer;
