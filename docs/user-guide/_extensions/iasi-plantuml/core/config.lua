local Config = {}

local function copy_table(source)
  local target = {}

  for key, value in pairs(source or {}) do
    target[key] = value
  end

  return target
end

local function merge_values(target, values, metadata)
  if values == nil then
    return
  end

  for key, value in pairs(values) do
    target[key] = metadata.value(value, target[key])
  end
end

local function normalize_cache(value)
  if value == true or value == false then
    return value
  end

  local text = tostring(value):lower()

  if text == "true" then
    return true
  elseif text == "false" then
    return false
  elseif text == "clean" then
    return "clean"
  end

  error(
    "Valor de cache no valido: "
      .. tostring(value)
      .. '. Use true, false o "clean".'
  )
end

function Config.load(meta, engine_name, defaults, metadata)
  local result = copy_table(defaults)

  -- Compatibilidad con la configuración utilizada por las primeras versiones.
  local engines = meta.engines
  if engines ~= nil then
    merge_values(result, engines[engine_name], metadata)
  end

  -- Contrato público de configuración de la extensión.
  local filter_options = meta["filter-options"]
  if filter_options ~= nil then
    merge_values(result, filter_options[engine_name], metadata)
  end

  result.enabled = metadata.boolean(result.enabled, true)
  result.cache = normalize_cache(result.cache)

  return result
end

return Config
