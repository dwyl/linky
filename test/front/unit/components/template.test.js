import { createRenderer } from 'react-addons-test-utils';
import React              from 'react';
import test               from 'tape';

import TemplateComponent from '../../../../src/js/components/template.js';

test('Shallow render template component', t => {
  let actual, expected;
  const shallowRender = createRenderer();
  const mockProps     = {
    changeTemplate : () => {},
    template       : ['hello', 'world']
  };

  let templateRender, list;

  shallowRender.render(<TemplateComponent {...mockProps} />);

  templateRender = shallowRender.getRenderOutput();
  list           = templateRender.props.children[1];

  actual   = list.props.children;
  expected = 'hello world';
  t.equal(actual, expected, 'state array mapped into child div');

  t.end();
});
