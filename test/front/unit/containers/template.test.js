import { createRenderer } from 'react-addons-test-utils';
import React              from 'react';
import test               from 'tape';

import {
  TemplateContainer,
  mapStateToProps
} from '../../../../src/js/containers/template.js';

test('TemplateContainer', t => {
  let actual, expected;
  const shallowRender = createRenderer();
  const mockProps     = { template: ['hello', 'world'] };
  const mockState     = { template: 'test' };

  shallowRender.render(<TemplateContainer {...mockProps}/>);

  const templateRender = shallowRender.getRenderOutput();
  const child          = templateRender.props.children;

  actual   = mapStateToProps(mockState).template;
  expected = 'test';
  t.equal(actual, expected, 'state mapped to props');

  actual   = child.type.displayName;
  expected = 'Template';
  t.equal(actual, expected, 'child has corrent props');

  actual   = child.props.template;
  expected = mockProps.template;
  t.deepEqual(actual, expected, "props passed to child");

  t.end();
});
