import React, { Component, PropTypes } from 'react';
import { connect }                     from 'react-redux';

import Template            from '../components/template.js';
import * as ActionCreators from '../actions/template.js';

export class TemplateContainer extends Component {

  render () {
    return (
      <div>
        <Template {...this.props} />
      </div>
    );
  }
}

TemplateContainer.propTypes = {
  template       : PropTypes.array,
  changeTemplate : PropTypes.func
};

export const mapStateToProps = state => {
  return {template: state.template};
};

export default connect(mapStateToProps, ActionCreators)(TemplateContainer);
