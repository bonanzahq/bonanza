import { Controller } from "@hotwired/stimulus"
import bootstrap from "../bootstrap/index.umd.js"

// Connects to data-controller="modal"
export default class extends Controller {
  connect() {
  }

  showModal(event){
    event.preventDefault()

    new bootstrap.Modal(document.getElementById(event.params.modalid), {
      keyboard: true,
      backdrop: true,
      focus: true
    }).show()

  }
}
