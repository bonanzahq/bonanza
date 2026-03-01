// ABOUTME: Stimulus controller for dynamically adding and removing link fields in a form.
// ABOUTME: Handles the add/remove pattern with show/hide logic for the empty state.
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="links-input"
export default class extends Controller {
  connect() {
    let itemCount = this.element.querySelectorAll(".input-group").length
    let l = this.element.querySelectorAll(".input-group")[itemCount-1]
    this.initialMaxId = parseInt(l.querySelector("input").id.match(/\d+/)[0])

    // Disable required on hidden rows so they don't block form submission
    this.element.querySelectorAll(".input-group.d-none [name*='\\[url\\]']").forEach(function(field) {
      field.required = false
    })
  }

  addLink(e){
    e.preventDefault()

    if(this.element.querySelectorAll(".input-group.d-none").length == 1) {
      this.element.querySelector(".input-group").classList.remove("d-none")
      this.element.querySelector("[name*='\\[title\\]']").value = ''
      const urlField = this.element.querySelector("[name*='\\[url\\]']")
      urlField.value = ''
      urlField.required = true
      this.element.querySelector("[name*='\\[_destroy\\]']").value = false

      this.element.querySelector(".input-group").appendChild(this.element.querySelector("[name*='\\[id\\]']"))
      this.element.querySelector(".input-group").appendChild(this.element.querySelector("[name*='\\[_destroy\\]']"))

      this.element.querySelector(".note").classList.add("d-none")

    } else {
      this.initialMaxId = this.initialMaxId+1

      let initialMaxId = this.initialMaxId

      const placeholder = document.createElement("div")
      placeholder.insertAdjacentElement('beforeend', e.target.parentNode.previousElementSibling.cloneNode(true))
      const lastLink = placeholder.firstElementChild

      lastLink.querySelectorAll("input").forEach(function(e){
        e.id = e.id.replace(/[0-9]+/g, initialMaxId)
        e.name = e.name.replace(/[0-9]+/g, initialMaxId)

        if(e.name.indexOf("[id]") != -1) {
          e.value = ''
        }

        if(e.name.indexOf("[title]") != -1) {
          e.value = ''
        }

        if(e.name.indexOf("[url]") != -1) {
          e.value = ''
        }

      })

      this.element.querySelector(".note").classList.add("d-none")

      e.target.parentNode.parentNode.insertBefore(lastLink, e.target.parentNode)
    }
  }

  removeLink(e) {
    e.preventDefault()

    let link = e.target.parentNode

    if( link.querySelector("[name*='\\[id\\]']") && link.querySelector("[name*='\\[id\\]']").value != "" ) {
      link.parentNode.appendChild(link.querySelector("[name*='\\[id\\]']"))
      link.querySelector("[name*='\\[_destroy\\]']").value = true
      link.parentNode.appendChild(link.querySelector("[name*='\\[_destroy\\]']"))
    }

    const urlField = link.querySelector("[name*='\\[url\\]']")
    if (urlField) urlField.required = false

    link.classList.add("d-none")

    if( this.element.querySelectorAll(".input-group").length > 1 ){
      link.remove()
    } else {
      this.element.querySelector(".note").classList.remove("d-none")
    }

  }
}
