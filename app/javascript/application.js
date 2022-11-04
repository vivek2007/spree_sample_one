// Entry point for the build script in your package.json
require("@rails/ujs").start()
import Rails from "@rails/ujs";

window.Rails = Rails;
if(Rails.fire(document, "rails:attachBindings")) {
    Rails.start();
}