import { Controller } from "@hotwired/stimulus"
import { format, render, cancel, register } from 'timeago.js'
import { de as locale_DE } from 'timeago.js/lib/lang';

// Connects to data-controller="timeago"
export default class extends Controller {
  connect() {

    register('de', locale_DE);

    render(this.element, 'de');

  }
}
