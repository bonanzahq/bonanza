import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pagination"
export default class extends Controller {
  static values = {
        url: String,
        page: Number,
        scroll: Boolean
  }

  connect() {
  }

  // replacePartial(event) {
  //   event.preventDefault();
  //   event.stopPropagation();

  //   const [, , xhr] = event.detail;

  //   if (event.target.classList.contains('js-action')) {
  //     this.replaceTarget.innerHTML = xhr.responseText;
  //   }
  // }

}
