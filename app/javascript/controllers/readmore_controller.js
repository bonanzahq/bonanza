import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="readmore"
export default class extends Controller {
  connect() {

    // this.element.classList.remove('slideInRight');
    // this.element.classList.add('fadeOut');

    if ( this.element.offsetHeight >= 240 ) {

      let wrapper = document.createElement('div');
      wrapper.classList.add('read-more-wrapper')

      wrapper.insertAdjacentHTML(
        'afterbegin',
        `
        <div class="content">
          <div class="inner"></div>
        </div>
        <div class="link">
          <a href="#" data-action="click->readmore#toggleContent">Mehr</a>
        </div>
        `
      )

      let content = wrapper.querySelector('.content .inner')

      while (this.element.firstChild) {
        let childElement = this.element.firstChild;
        content.appendChild(childElement);
      }

      this.element.appendChild(wrapper)

    }
  }

  toggleContent(e) {
    e.preventDefault()

    let wrapper = this.element.querySelector('.read-more-wrapper')
    if(wrapper.classList.contains('more')) {
      wrapper.querySelector('.link a').text = "Mehr"
      wrapper.classList.remove('more')
    } else {
      wrapper.classList.add('more')
      wrapper.querySelector('.link a').text = "Weniger"
    }
  }
}
