import test from 'tape';

import createStore from '../../../src/js/create_store.js';

test('create store', t => {
  let actual;
  const store          = createStore();
  const correctMethods = ['dispatch', 'subscribe', 'getState', 'replaceReducer']
    .reduce((result, method) => result && method in store, true);

  actual = correctMethods;
  t.ok(actual, 'createStore returns instance of store');

  t.end();
});
