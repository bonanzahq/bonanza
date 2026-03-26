import { Controller } from "@hotwired/stimulus"
import dayjs from 'dayjs'
import 'dayjs/locale/de'
import { calculatePickerDate, calculateReturnDuration } from '../utils/lending_duration.mjs'
import Pikaday from 'pikaday'

// Connects to data-controller="datepicker"
export default class extends Controller {

  static targets = [ "input", "output" ]

  static values = {
    startdate: String
  }

  connect() {
    let output = this.outputTarget
    let startdate = this.startdateValue
    let defaultDate = calculatePickerDate(startdate, this.outputTarget.value)

    let picker = new Pikaday({
      field: this.inputTarget,
      firstDay: 1,
      minDate: dayjs().add(1, 'day').toDate(),
      defaultDate: defaultDate,
      setDefaultDate: defaultDate != null,
      format: 'dd. DD.MM.YY',
      toString(date, format) {
          return dayjs(date).locale('de').format(format);
      },
      parse(dateString, format) {
          return dayjs(dateString, format);
      },
      onSelect: function(date) {
        picker.setEndRange(date)
        output.value = calculateReturnDuration(date, startdate)
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

    let startRangeDate = dayjs(startdate, 'YYYY-MM-DD').toDate()

    this.picker.setStartRange(startRangeDate)
    if (defaultDate != null) {
      this.picker.setEndRange(defaultDate)
    }
    this.picker.draw()
  }

  setDateinPicker() {
    if( this.outputTarget ) {
      let date = calculatePickerDate(this.startdateValue, this.outputTarget.value)
      if (date != null) {
        this.picker.setDate(date)
      }
    }
  }

}
