import React, { Component, PropTypes } from 'react';

class Template extends Component {

  render () {
    const { template, changeTemplate } = this.props;

    return (
      <div className='template_component'>
        <button onClick = {changeTemplate.bind(this, 'CHANGE')} >click me!</button>
        <div>{template.join(' ')}</div>
      </div>
    );
  }
}

Template.propTypes = {
  template       : PropTypes.array,
  changeTemplate : PropTypes.func
};

Template.displayName = 'Template';

export default Template;
