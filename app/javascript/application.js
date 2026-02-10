// Entry point for the build script in your package.json
import "@hotwired/turbo-rails"

import "./controllers"
import bootstrap from "./bootstrap/index.umd.js"

// addValidator("equalTo", equalTo)

// function equalTo(element) {
//   const { value } = element

//   return new Promise(async (resolve, reject) => {

//     const origName = element.getAttribute('name')

//     let otherElement = document.querySelector("[name='" + origName.replace("_confirmation", "") + "']")

//     value == otherElement.value ? resolve() : reject("Beide Passwörter stimmen nicht überein")
//   })
// }


