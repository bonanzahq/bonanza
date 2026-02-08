import { Controller } from "@hotwired/stimulus"
import dayjs from 'dayjs'
import 'dayjs/locale/de'

var Pikaday = require('pikaday');

window.Pikaday = Pikaday;

// Connects to data-controller="datepicker"
export default class extends Controller {

  static targets = [ "input", "output" ]

  static values = {
    startdate: String
  }

  connect() {
    let output = this.outputTarget
    let defaultDate = dayjs(this.startdateValue, 'YYYY-MM-DD').add(parseInt(this.outputTarget.value), 'day').toDate()

    let picker = new Pikaday({
      field: this.inputTarget,
      firstDay: 1,
      minDate: dayjs().add(1, 'day').toDate(),
      defaultDate: defaultDate,
      setDefaultDate: true,
      format: 'dd. DD.MM.YY',
      toString(date, format) {
          return dayjs(date).locale('de').format(format);
      },
      parse(dateString, format) {
          return dayjs(dateString, format);
      },
      onSelect: function(date) {
        picker.setEndRange(date)
        output.value = dayjs(date).diff(dayjs(), 'day') + 1
      },
      i18n: {
        previousMonth : 'vorheriger Monat',
        nextMonth     : 'Nächster Monat',
        months        : ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'],
        weekdays      : ['Sonntag','Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag'],
        weekdaysShort : ['So','Mo','Di','Mi','Do','Fr','Sa']
      }
    })

    this.picker = picker

    let startRangeDate = dayjs(this.startdateValue, 'YYYY-MM-DD').toDate()

    this.picker.setStartRange(startRangeDate)
    this.picker.setEndRange(defaultDate)
    this.picker.draw()
  }

  setDateinPicker() {
    if( this.outputTarget ) {
      this.picker.setDate(dayjs().add(parseInt(this.outputTarget.value), 'day').toDate())  
    }
  }

}
