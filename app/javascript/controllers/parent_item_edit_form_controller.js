import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="parent-item-edit-form"
export default class extends Controller {

  // static targets = [ "form" ]

  connect() {
  }

  submitForm(e) {
    e.preventDefault()

    if(document.querySelector('#amount').classList.contains('active')) {
      this.uniqueHtml = document.querySelector('#unique').innerHTML

      document.querySelectorAll('#unique .item').forEach(function(item, i ){
        item.querySelector("[name*='\\[uid\\]']").remove()
        
        if (i > 0 ) {
          item.querySelector("[name*='\\[_destroy\\]']").value = true  
        }
      })
    } else {
       this.amountHtml = document.querySelector('#amount').innerHTML
      document.querySelector('#amount').innerHTML = ''
    }

    if (this.element.checkValidity()) {
      this.element.submit()  
    } else {

      if(document.querySelector('#amount').classList.contains('active')) {
        document.querySelector('#unique').innerHTML = this.uniqueHtml
      } else {
         document.querySelector('#amount').innerHTML = this.amountHtml
      }

      this.element.reportValidity()

      let errorItem = document.querySelector('.field-error')
      errorItem.focus()
      errorItem.scrollIntoView({behavior: 'smooth', block: 'center'})
      e.target.blur()

    }
  }
}
