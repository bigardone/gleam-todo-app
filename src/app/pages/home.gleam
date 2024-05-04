import lustre/element.{type Element}
import lustre/element/html

pub fn root() -> Element(t) {
  html.h1([], [html.text("Homepage")])
}
