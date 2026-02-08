import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="accessories-input"
export default class extends Controller {
  connect() {
    let itemCount = this.element.querySelectorAll(".input-group").length
    let l = this.element.querySelectorAll(".input-group")[itemCount-1]
    this.initialMaxId = parseInt(l.querySelector("input").id.match(/\d+/)[0])
  }

  addAccessory(e){
    e.preventDefault()

    if(this.element.querySelectorAll(".input-group.d-none").length == 1) {
      this.element.querySelector(".input-group").classList.remove("d-none")
      this.element.querySelector("[name*='\\[name\\]']").value = ''
      this.element.querySelector("[name*='\\[_destroy\\]']").value = false

      this.element.querySelector(".input-group").appendChild(this.element.querySelector("[name*='\\[id\\]']"))
      this.element.querySelector(".input-group").appendChild(this.element.querySelector("[name*='\\[_destroy\\]']"))

      this.element.querySelector(".note").classList.add("d-none")

    } else {
      this.initialMaxId = this.initialMaxId+1

      let initialMaxId = this.initialMaxId

      const placeholder = document.createElement("div")
      placeholder.insertAdjacentElement('beforeend', e.target.parentNode.previousElementSibling.cloneNode(true))
      const lastAccessory = placeholder.firstElementChild

      lastAccessory.querySelectorAll("input").forEach(function(e){
        e.id = e.id.replace(/[0-9]+/g, initialMaxId)
        e.name = e.name.replace(/[0-9]+/g, initialMaxId)

        if(e.name.indexOf("[id]") != -1) {
          e.value = ''
        }

        if(e.name.indexOf("[name]") != -1) {
          e.value = ''
        }

      })

      this.element.querySelector(".note").classList.add("d-none")

      e.target.parentNode.parentNode.insertBefore(lastAccessory, e.target.parentNode)
    }
  }

  removeAccessory(e) {
    e.preventDefault()

    let accessory = e.target.parentNode

    if( accessory.querySelector("[name*='\\[id\\]']") && accessory.querySelector("[name*='\\[id\\]']").value != "" ) {
      accessory.parentNode.appendChild(accessory.querySelector("[name*='\\[id\\]']"))
      accessory.querySelector("[name*='\\[_destroy\\]']").value = true
      accessory.parentNode.appendChild(accessory.querySelector("[name*='\\[_destroy\\]']"))
    }

    accessory.classList.add("d-none")

    if( this.element.querySelectorAll(".input-group").length > 1 ){
      accessory.remove()
    } else {
      this.element.querySelector(".note").classList.remove("d-none")
    }
    
  }
}
