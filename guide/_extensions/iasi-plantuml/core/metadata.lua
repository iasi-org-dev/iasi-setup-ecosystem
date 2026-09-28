local Metadata = {}

function Metadata.value(value, default)
  if value == nil then
    return default
  end

  local value_type = pandoc.utils.type(value)

  if value_type == "Inlines" or value_type == "Blocks" then
    return pandoc.utils.stringify(value)
  end

  if value_type == "List" then
    local result = {}

    for _, item in ipairs(value) do
      table.insert(result, Metadata.value(item))
    end

    return result
  end

  if type(value) == "table" then
    local result = {}

    for key, item in pairs(value) do
      result[key] = Metadata.value(item)
    end

    return result
  end

  return value
end

function Metadata.boolean(value, default)
  value = Metadata.value(value, default)

  if type(value) == "boolean" then
    return value
  end

  local text = tostring(value):lower()

  if text == "true" then
    return true
  end

  if text == "false" then
    return false
  end

  return default
end

return Metadata
