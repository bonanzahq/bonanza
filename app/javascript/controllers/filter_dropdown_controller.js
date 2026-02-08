import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="filter-dropdown"
export default class extends Controller {
  static targets = [ "amount", "input" ]

  connect() {
    let amount = this.inputTargets.filter(x => x.checked ).length
    
    this.amountTarget.classList.toggle("d-none", amount == 0 );
    this.amountTarget.innerHTML = amount;
  }

  trackAmount() {
    let amount = this.inputTargets.filter(x => x.checked ).length
    
    this.amountTarget.classList.toggle("d-none", amount == 0 );
    this.amountTarget.innerHTML = amount;


    // TOOD: update turbo frame to only update the results of the form. currently seems like full form is replaced
    this.inputTargets[0].form.requestSubmit()
  }

}
