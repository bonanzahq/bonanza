import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="sidebar-cart"
export default class extends Controller {
  connect() {

    console.log("connected")

    document.addEventListener("turbo:load", (e) => {

      if(document.querySelector("#sidebar-cart .actions")) {
        if (e.detail.url.includes("checkout")) {
          document.querySelector("#sidebar-cart .actions").classList.add("d-none")
        } else {
          document.querySelector("#sidebar-cart .actions").classList.remove("d-none")
        }
      }
      
    })
    //turbo:load
  }
}
