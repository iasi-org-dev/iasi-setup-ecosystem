local MediaBag = {}

local function caption_to_inlines(text)
  if text == nil or text == "" then
    return pandoc.Inlines({})
  end

  local document = pandoc.read(text, "markdown")
  local result = pandoc.Inlines({})

  for _, block in ipairs(document.blocks) do
    if block.t == "Para" or block.t == "Plain" then
      if #result > 0 then
        result:insert(pandoc.Space())
      end

      result:extend(block.content)
    end
  end

  return result
end

local function image_attributes(block)
  local attributes = {}

  for key, value in pairs(block.attributes) do
    if key ~= "server"
      and key ~= "format"
      and key ~= "cache"
      and key ~= "fig-cap"
      and key ~= "caption"
      and key ~= "label"
    then
      attributes[key] = value
    end
  end

  return attributes
end

function MediaBag.publish(block, path, mime_type, contents)
  pandoc.mediabag.insert(path, mime_type, contents)

  local caption = caption_to_inlines(
    block.attributes["fig-cap"]
      or block.attributes["caption"]
      or ""
  )

  local identifier = block.identifier

  if identifier == nil or identifier == "" then
    identifier = block.attributes["label"] or ""
  end

  local image = pandoc.Image(
    caption,
    path,
    "",
    pandoc.Attr(identifier, {}, image_attributes(block))
  )

  return pandoc.Para({ image })
end

return MediaBag
