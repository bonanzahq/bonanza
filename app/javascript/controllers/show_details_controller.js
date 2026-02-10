import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="show-lender-details"
export default class extends Controller {
  connect() {
  }

  toggleDetails(e) {
    e.preventDefault()
    this.element.querySelector(".body").classList.toggle("d-none")
  }
}
