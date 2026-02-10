import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="depts-selector"
export default class extends Controller {

  connect() {
  }

  setDept(event) {
    //console.log(event.target.value)
    console.log("dispatching event")
    this.dispatch("setDept", { target: document, detail: { content: event.target.value } })
  }

}
