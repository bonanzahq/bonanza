import { Controller } from "@hotwired/stimulus"
import Tagify from "@yaireo/tagify"

// Connects to data-controller="tags-input"
export default class extends Controller {
  connect() {
    this.tagifyObject = new Tagify(this.element, {
      originalInputValueFormat: valuesArr => valuesArr.map(item => item.value).join(',')
    })
  }
}
