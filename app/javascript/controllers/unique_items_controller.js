import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="unique-items"
export default class extends Controller {

  static targets = [ "items" ]

  static values = {
    itemHtml: String,
    initialMaxId: Number
  }

  connect() {
    this.itemHtmlValue = document.querySelector("#unique .item").outerHTML

    let itemCount = this.itemsTarget.querySelectorAll(".item").length
    let l = this.itemsTarget.querySelectorAll(".item")[itemCount-1]
    this.initialMaxIdValue = parseInt(l.querySelector("input").id.match(/\d+/)[0])
  }

  addItem() {
    const placeholder = document.createElement("div")
    placeholder.innerHTML = this.itemHtmlValue
    const lastItem = placeholder.firstElementChild

    let initialMaxId = this.initialMaxIdValue

    lastItem.querySelectorAll("input, textarea").forEach(function(e){
      e.removeAttribute("disabled")

      if(e.name.indexOf("[condition]") == -1) {
        e.value = ''
      } else {
        e.removeAttribute("checked")
        e.setAttribute("data-visited", "true")
      }

      if(e.name.indexOf("[quantity]") != -1) {
        e.value = 1
      }

      e.id = e.id.replace(/[0-9]+/g, initialMaxId+1)
      e.name = e.name.replace(/[0-9]+/g, initialMaxId+1)
    })

    lastItem.querySelectorAll("label").forEach(function(e){
      e.htmlFor = e.htmlFor.replace(/[0-9]+/g, initialMaxId+1)
    })

    lastItem.querySelector(".remove").style.display = 'inline'
    lastItem.querySelector(".lent").remove()

    this.itemsTarget.insertAdjacentElement('beforeend', lastItem)

    lastItem.querySelector("input").focus()
    lastItem.scrollIntoView()

    this.initialMaxIdValue = this.initialMaxIdValue+1

    let nodes = this.itemsTarget.querySelectorAll(".item")
    this.reassignIds(nodes)
  }

  removeItem(e) {
    let item = e.target.closest('.item')

    if( item != this.itemsTarget.querySelector(".item") ) {

      if( item.querySelector("[name*='\\[id\\]']").value != "" ) {
        this.itemsTarget.appendChild(item.querySelector("[name*='\\[id\\]']"))
        item.querySelector("[name*='\\[_destroy\\]']").value = true
        this.itemsTarget.appendChild(item.querySelector("[name*='\\[_destroy\\]']"))
      }

      item.remove()
      
    }

    let nodes = this.itemsTarget.querySelectorAll(".item")

    this.reassignIds(nodes)
  }

  reassignIds(nodes) {
    nodes.forEach(function(elem, i){

      elem.querySelector("h5 span").innerHTML = i+1

    })
  }
}
