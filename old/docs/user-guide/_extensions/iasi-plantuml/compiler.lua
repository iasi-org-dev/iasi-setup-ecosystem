local Compiler = {}

local OUTPUT_FORMAT = "png"
local STATUS_MARKER = "\nIASI_PLANTUML_HTTP_STATUS:"

local SUPPORTED_FORMATS = {
  png = "image/png",
  svg = "image/svg+xml"
}

local function fail(message)
  assert(false, message)
end

local function warn(message)
  if quarto ~= nil
    and quarto.log ~= nil
    and quarto.log.warning ~= nil
  then
    quarto.log.warning(message)
    return
  end

  io.stderr:write("WARNING: " .. message .. "\n")
end

local function trim_trailing_slash(value)
  return (value:gsub("/+$", ""))
end

local function normalize_styles(styles)
  if styles == nil then
    return {}
  end

  if type(styles) == "table" then
    return styles
  end

  return { tostring(styles) }
end

local function read_file(path)
  local file, message = io.open(path, "rb")

  if file == nil then
    fail(
      "No se pudo leer el estilo PlantUML "
        .. tostring(path)
        .. ": "
        .. tostring(message)
    )
  end

  local contents = file:read("*a")
  file:close()

  return contents
end

local function inject_after_startuml(source, styles_source)
  if styles_source == "" then
    return source
  end

  local _, end_position = source:find("@startuml[^\r\n]*")

  if end_position == nil then
    return styles_source .. "\n" .. source
  end

  return source:sub(1, end_position)
    .. "\n"
    .. styles_source
    .. "\n"
    .. source:sub(end_position + 1)
end

local function validate_format(format)
  format = tostring(format):lower()

  if SUPPORTED_FORMATS[format] == nil then
    local supported = {}

    for name, _ in pairs(SUPPORTED_FORMATS) do
      table.insert(supported, name)
    end

    table.sort(supported)

    fail(
      "Formato PlantUML no soportado: "
        .. format
        .. ". Formatos soportados: "
        .. table.concat(supported, ", ")
        .. "."
    )
  end

  return format
end

local function pipe_error_detail(problem)
  if type(problem) ~= "table" then
    return tostring(problem)
  end

  local parts = {}

  if problem.error_code ~= nil then
    table.insert(
      parts,
      "codigo curl: " .. tostring(problem.error_code)
    )
  end

  if problem.output ~= nil and problem.output ~= "" then
    table.insert(parts, tostring(problem.output))
  end

  if #parts == 0 then
    return tostring(problem)
  end

  return table.concat(parts, "\n")
end

local function valid_contents(format, contents)
  if format == "png" then
    return contents:sub(1, 8) == "\137PNG\r\n\26\n"
  end

  if format == "svg" then
    return contents:find("<svg", 1, true) ~= nil
  end

  return false
end

local function split_response(response)
  local marker_position
  local search_from = 1

  while true do
    local position = response:find(
      STATUS_MARKER,
      search_from,
      true
    )

    if position == nil then
      break
    end

    marker_position = position
    search_from = position + 1
  end

  if marker_position == nil then
    return nil, nil
  end

  local status_text = response:sub(
    marker_position + #STATUS_MARKER
  )

  if not status_text:match("^%d%d%d$") then
    return nil, nil
  end

  return response:sub(1, marker_position - 1), tonumber(status_text)
end

local function printable_excerpt(contents)
  local excerpt = contents:sub(1, 1000)

  excerpt = excerpt:gsub(
    "[%z\1-\8\11\12\14-\31]",
    "?"
  )

  return excerpt
end

function Compiler.normalize_config(config)
  config.format = OUTPUT_FORMAT
  return config
end

function Compiler.prepare(source, config)
  local style_files = normalize_styles(config.styles)

  if #style_files == 0 then
    return source
  end

  local fragments = {}

  for _, style_file in ipairs(style_files) do
    table.insert(fragments, read_file(tostring(style_file)))
  end

  return inject_after_startuml(
    source,
    table.concat(fragments, "\n")
  )
end

function Compiler.mime_type(config)
  local format = validate_format(config.format)

  return SUPPORTED_FORMATS[format]
end

function Compiler.compile(source, config)
  local format = validate_format(config.format)
  local url = trim_trailing_slash(tostring(config.server))
    .. "/"
    .. format
    .. "/"

  local ok, response_or_problem = pcall(
    pandoc.pipe,
    "curl",
    {
      "--silent",
      "--show-error",
      "--location",
      "--request",
      "POST",
      "--header",
      "Content-Type: text/plain; charset=utf-8",
      "--data-binary",
      "@-",
      "--write-out",
      STATUS_MARKER .. "%{http_code}",
      url
    },
    source
  )

  if not ok then
    fail(
      "No se pudo ejecutar la peticion POST a PlantUML.\n"
        .. "URL: "
        .. url
        .. "\nDetalle: "
        .. pipe_error_detail(response_or_problem)
    )
  end

  local contents, status = split_response(response_or_problem)

  if status == nil then
    fail(
      "curl no devolvio un estado HTTP reconocible.\n"
        .. "URL: "
        .. url
    )
  end

  if contents == "" then
    fail(
      "PlantUML devolvio una respuesta vacia.\n"
        .. "HTTP: "
        .. tostring(status)
        .. "\nURL: "
        .. url
    )
  end

  if status >= 200 and status < 300 then
    if not valid_contents(format, contents) then
      fail(
        "PlantUML devolvio un contenido inesperado.\n"
          .. "HTTP: "
          .. tostring(status)
          .. "\nFormato esperado: "
          .. format
          .. "\nURL: "
          .. url
          .. "\nRespuesta:\n"
          .. printable_excerpt(contents)
      )
    end

    return SUPPORTED_FORMATS[format], contents, {
      cacheable = true,
      diagnostic = false
    }
  end

  if not valid_contents(format, contents) then
    fail(
      "PlantUML rechazo la peticion sin devolver una imagen de diagnostico.\n"
        .. "HTTP: "
        .. tostring(status)
        .. "\nURL: "
        .. url
        .. "\nRespuesta:\n"
        .. printable_excerpt(contents)
    )
  end

  warn(
    "PlantUML no pudo compilar un diagrama. "
      .. "La imagen de diagnostico se incluira en el documento.\n"
      .. "HTTP: "
      .. tostring(status)
  )

  return SUPPORTED_FORMATS[format], contents, {
    cacheable = false,
    diagnostic = true
  }
end

return Compiler
