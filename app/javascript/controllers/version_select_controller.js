import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="version-select"
export default class extends Controller {
  connect() {
    console.log("Connected")
  }

  change(event) {
    const frame = document.getElementById('tos');
    frame.src=event.target.value;
  }
}
