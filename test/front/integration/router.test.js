import { createRenderer } from 'react-addons-test-utils';
import React              from 'react';
import test               from 'tape';

import Router from '../../../src/js/router.js';

test('RouterContainer', t => {
  let actual, expected;
  let renderOutput, shallowRender;

  shallowRender = createRenderer();
  shallowRender.render(<Router />);

  renderOutput = shallowRender.getRenderOutput();

  actual   = renderOutput.type.displayName;
  expected = 'Router';
  t.equal(actual, expected, 'Router component has displayName \'Router\'');

  t.end();
});
