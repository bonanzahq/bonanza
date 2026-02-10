import { Controller } from "@hotwired/stimulus"
import bootstrap from "../bootstrap/index.umd.js"

// Connects to data-controller="inline-tabs"
export default class extends Controller {

  static values = {
    tab: String,
    tabContent: Object,
    lent: Boolean
  }

  connect() {
  }

  confirmChange(event) {
    this.clickTarget = event.target

    if ( !event.target.classList.contains("active") ) {

      if ( this.lentValue ) {

        var myModal = new bootstrap.Modal(document.getElementById('lentModal'), {
          keyboard: true,
          backdrop: true,
          focus: true
        }).show()

      } else {

        var myModal = new bootstrap.Modal(document.getElementById('myModal'), {
          keyboard: true,
          backdrop: true,
          focus: true
        }).show()

        this.tabValue = event.params.tab

      }
      
    }
  }

  show() {
    var myModalEl = document.getElementById('myModal')

    bootstrap.Modal.getInstance(myModalEl).hide()
    
    document.querySelectorAll('.bnz-tab-navigation a').forEach(function (item) {
      item.classList.remove("show")
      item.classList.remove("active")
    })

    document.querySelectorAll('.tab-pane').forEach(function (item) {
      item.classList.remove("show")
      item.classList.remove("active")
    })

    let currentTab = document.querySelector(this.tabValue)

    currentTab.classList.add("show")
    currentTab.classList.add("active")

    if(this.tabValue == "#unique") {
      this.element.closest("form").reportValidity()

      let errorItem = document.querySelector('.field-error')
      
      if( errorItem ) {
        errorItem.focus()
        errorItem.scrollIntoView({behavior: 'smooth', block: 'center'})
      }
      
    }

    this.clickTarget.classList.add("active")

  }
}
