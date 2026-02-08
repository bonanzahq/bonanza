import { Controller } from "@hotwired/stimulus"
import autoComplete from "@tarekraafat/autocomplete.js";

// Connects to data-controller="autocomplete"
export default class extends Controller {

  static targets = [ "input" ]

  static values = {
    source: String,
    dept: String
  }

  connect() {

    let config = {
      selector: () => {
          return this.inputTarget;
      },
      data: {
          src: async () => {
              try {
                  let sourceUrl = this.sourceValue

                  if ( this.hasDeptValue ) {
                    sourceUrl += this.deptValue 
                  }

                  // Fetch External Data Source
                  const source = await fetch( sourceUrl );
                  const data = await source.json();
                  // Returns Fetched data
                  return data;
              } catch (error) {
                  return error;
              }
          },
          cache: true,
          filter: list => {
              console.log("filtering...");

              // add fuse logic for order

              // sort result list alphabetically
              list.sort((b,a) => {
                  return b.match.localeCompare(a.match);
              });
              
              // no need to continue if we have less then the maxResults variable
              if (list.length < autoCompleteJS.resultsList.maxResults) {
                  return list;
              }
              
              list.sort((item) => {
                  const inputValue = autoCompleteJS.input.value.toLowerCase()
                  const itemValue = item.match.toLowerCase()
              
                  if (itemValue.startsWith(inputValue)) {
                      return -1;
                  }
                  return 1;
              
              });
              
              return list;
              
          }

        },

        submit: true,
        resultItem: {
            highlight: false
        },
        threshold: 0,
        events: {
            input: {
                selection: (event) => {
                    const selection = event.detail.selection.value
                    autoCompleteJS.input.value = selection
                    autoCompleteJS.input.form.requestSubmit()

                    if (this.inputTarget.value != "") {
                      newNode.classList.add("visible")
                    }
                },
                focus() {
                    autoCompleteJS.start()
                }
            }
        }
    }

    if( document.getElementsByClassName('autoComplete_wrapper').length > 0 ) {
      let parent = document.getElementsByClassName('autoComplete_wrapper')[0]
      parent.replaceWith(...parent.childNodes)

      document.getElementById('clear-button').remove()
    }

    this.autoCompleteJS = new autoComplete( config )
    let autoCompleteJS = this.autoCompleteJS

    // Create a new element
    var newNode = document.createElement('span')

    newNode.classList.add("clear-input", "icon", "remove")
    newNode.setAttribute("id","clear-button")

    // Get the reference node
    var referenceNode = this.inputTarget;

    // Insert the new node before the reference node
    referenceNode.after(newNode);

    if (this.inputTarget.value != "") {
        newNode.classList.add("visible")
    }

    newNode.addEventListener("click", function (event) {
        referenceNode.value = ""
        newNode.classList.remove("visible")
        referenceNode.form.requestSubmit()
    })

    referenceNode.addEventListener('input', function (event) {
      if (referenceNode.value == "") {
        newNode.classList.remove("visible")
      } else {
        newNode.classList.add("visible")
      }
    })

    // this.element.addEventListener("submit", (event) => {
    //   console.log("updating url")
    //   this.updateUrlParameters()
    // })

  }

  setSource({ detail: { content }}) {
    // this.element.querySelector('input[name="dept"]').value = content
    this.fetchNewItems(content)
    //this.element.submit()
  }

  // updateUrlParameters(){
  //   const url = new URL(window.location)
  //   url.searchParams.set('q', this.inputTarget.value)
  //   window.history.pushState({}, '', url)
  // }

  async fetchNewItems(val) {
    try {
      console.log("fetching new items")
      //let sourceUrl = "http://localhost:3000/autocomplete/items.json"

      let sourceUrl = this.sourceValue

      if( val == 'all' ) {
        sourceUrl += "all"
      } else if (parseInt(val) && parseInt(val) >= 0) {
        sourceUrl += parseInt(val)
      }

      // Fetch External Data Source
      const source = await fetch(sourceUrl)
      const data = await source.json()
      
      this.autoCompleteJS.data.store = data

      console.log("Fetched " + data.length + " entries")

      // this.element.submit()

    } catch (error) {
      console.error(error);
    }
  }

}
