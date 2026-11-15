if quarto.doc.is_format("html") then
  quarto.doc.add_html_dependency({
    name = "iasi",
    version = "1.0.0",
    scripts = {
      "../js/iasi.js"
    }
  })
end