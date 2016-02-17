import React        from 'react';
import ReactDOM     from 'react-dom';
import { Provider } from 'react-redux';

import createStore from './create_store.js';
import Router      from './router.js';
import '../css/index.js';

/* global document */
const node  = document.getElementById('react_content_container');
const store = createStore();

ReactDOM.render(
  <div id = 'react_content' className = 'react_content'>
    <Provider store = {store}>
      <Router/>
    </Provider>
  </div>
, node);
