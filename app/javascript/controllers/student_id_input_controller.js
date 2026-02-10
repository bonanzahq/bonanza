import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="student-id-input"
export default class extends Controller {
  connect() {
  }

  toggleInput(){
    if(this.element.value == "employee") {
      this.element.parentNode.classList.replace("mb-2", "mb-4")
      document.querySelector(".student-id").classList.add("d-none")
    } else {
      this.element.parentNode.classList.replace("mb-4", "mb-2")
      document.querySelector(".student-id").classList.remove("d-none")
    }
  }
}
