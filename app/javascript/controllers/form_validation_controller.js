import { Controller } from "@hotwired/stimulus"
import hyperform from 'hyperform';
import bootstrap from "../bootstrap/index.umd.js"

// Connects to data-controller="form-validation"
export default class extends Controller {
  connect() {
    this.validation = hyperform(this.element, {
      classes: {
        invalid: 'field-error',
        warning: 'invalid-feedback',
      }
    })

    this.addGermanTranslation()

    hyperform.setRenderer('attachWarning', function(warning, element) {
      if(element.classList.contains("form-check-input")) {
        element.closest(".check-input-container").appendChild(warning)
      } else {
        element.parentNode.appendChild(warning)  
      }
    })

    if(document.getElementById('borrower_student_id')) {
      hyperform.addValidator(
        document.getElementById('borrower_student_id'),
        function (element) {
          var valid = ! document.getElementById('borrower_borrower_type').value == "student" ||
                element.value
          element.setCustomValidity(
            valid?
              '' :
              'Studierende müssen ihre Martikelnummer angeben'
          )
          return valid
        }
      )

      document.getElementById('borrower_student_id').addEventListener('change', function() {
        document.getElementById('borrower_borrower_type').reportValidity()
      })
    }

    if(document.getElementById('user_password_confirmation')) {
      hyperform.addValidator(
        document.getElementById('user_password_confirmation'),
        function (element) {
          var valid = false

          valid = element.value == document.getElementById('user_password').value

          element.setCustomValidity(
            valid?
              '' :
              'Die Passwörter müssen übereinstimmen.'
          )
          return valid
        }
      )

      document.getElementById('user_password').addEventListener('invalid', function() {
        bootstrap.Collapse.getOrCreateInstance(document.getElementById('flush-collapseOne')).show()
      });

      document.getElementById('user_password_confirmation').addEventListener('invalid', function() {
        bootstrap.Collapse.getOrCreateInstance(document.getElementById('flush-collapseOne')).show()
      });
    }
  }

  addGermanTranslation() {

    hyperform.addTranslation("de",{
      TextTooLong:"Bitte kürze diesen Text auf maximal %l Zeichen (Du verwendest derzeit %l Zeichen).",
      TextTooShort:"Bitte verwende mindestens %l Zeichen (Du verwendest derzeit %l Zeichen).",
      ValueMissing:"Bitte fülle dieses Feld aus.",
      CheckboxMissing:"Bitte klicken Sie dieses Kästchen an, wenn Sie fortsetzen wollen.",
      RadioMissing:"Bitte wähle eine dieser Optionen.",
      FileMissing:"Bitte wähle eine Datei aus.",
      SelectMissing:"Bitte wähle einen Eintrag aus der Liste.",
      InvalidEmail:"Bitte gebe eine E-Mail-Adresse an.",
      InvalidURL:"Bitte gebe eine Internetadresse an.",
      //InvalidDate:"",
      PatternMismatch:"Bitte halte dich an das vorgegebene Format.",
      PatternMismatchWithTitle:"Bitte halte dich an das vorgegebene Format: %l.",
      NumberRangeOverflow:"Bitte wähle einen Wert, der nicht größer ist als %l.",
      DateRangeOverflow:"Bitte wähle einen Datum, welches nicht später ist als %l.",
      TimeRangeOverflow:"Bitte wähle eine Zeit, welche nicht später ist als %l.",
      NumberRangeUnderflow:"Bitte wähle einen Wert, der nicht kleiner ist als %l.",
      DateRangeUnderflow:"Bitte wähle ein Datum, welches nicht früher ist als %l.",
      TimeRangeUnderflow:"Bitte wähle eine Zeit, welche nicht früher ist als %l.",
      BadInputNumber:"Bitte gebe eine Nummer ein.",
      "Please match the requested type.": "Bitte passen Sie die Eingabe dem geforderten Typ an.",
      "Please comply with all requirements.": "Bitte erfüllen Sie alle Anforderungen.",
      "Please lengthen this text to %l characters or more (you are currently using %l characters).": "Bitte verwende mindestens %l Zeichen (Du verwendest derzeit %l Zeichen).",
      "Please use the appropriate format.": "Bitte verwenden Sie das passende Format.",
      "Please enter a comma separated list of email addresses.": "Bitte geben Sie eine komma-getrennte Liste von E-Mail-Adressen an.",
      "Please select a file of the correct type.": "Bitte wählen Sie eine Datei vom korrekten Typ.",
      "Please select one or more files.": "Bitte wählen Sie eine oder mehrere Dateien.",
      "any value":"jeder Wert",
      "any valid value":"jeder gültige Wert",
    });
    hyperform.setLanguage("de");

  }
}
