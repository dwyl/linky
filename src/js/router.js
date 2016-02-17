import React, { Component } from 'react';
import {
  Router as ReactRouter,
  Route
}                           from 'react-router';
import history              from './history.js';

import Template from './containers/template.js';

export default class Router extends Component {
  render () {
    return (
      <ReactRouter history = { history }>
        <Route path = '/' component = { Template } />
      </ReactRouter>
    );
  }
}
