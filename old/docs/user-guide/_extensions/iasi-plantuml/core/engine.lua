local Engine = {}

local function has_class(block, expected)
  for _, class_name in ipairs(block.classes) do
    if class_name == expected then
      return true
    end
  end

  return false
end

local function copy_config(config)
  local result = {}

  for key, value in pairs(config) do
    result[key] = value
  end

  return result
end

local function normalize_config(compiler, config)
  if compiler.normalize_config == nil then
    return config
  end

  return compiler.normalize_config(config) or config
end

local function merge_block_config(global_config, block, option_names)
  local result = copy_config(global_config)

  for _, key in ipairs(option_names or {}) do
    if block.attributes[key] ~= nil then
      result[key] = block.attributes[key]
    end
  end

  return result
end

local function cache_identity(source, config, specification)
  local parts = { source }

  for _, key in ipairs(specification.cache_keys or {}) do
    table.insert(parts, tostring(config[key] or ""))
  end

  table.insert(parts, tostring(specification.version or ""))

  return table.concat(parts, "\n")
end

function Engine.create(specification)
  assert(specification.name, "Falta specification.name")
  assert(specification.compiler, "Falta specification.compiler")
  assert(specification.defaults, "Falta specification.defaults")
  assert(specification.load_core, "Falta specification.load_core")

  local Metadata = specification.load_core("metadata")
  local Config = specification.load_core("config")
  local Filesystem = specification.load_core("filesystem")
  local Cache = specification.load_core("cache")
  local MediaBag = specification.load_core("mediabag")

  local function Pandoc(document)
    local config = Config.load(
      document.meta,
      specification.name,
      specification.defaults,
      Metadata
    )

    if config.enabled == false then
      return document
    end

    config = normalize_config(specification.compiler, config)

    local cache = Cache.open({
      filesystem = Filesystem,
      directory = pandoc.path.join({
        ".quarto",
        specification.name
      }),
      extension = tostring(config.format),
      mode = config.cache
    })

    local function CodeBlock(block)
      if not has_class(
        block,
        specification.block_class or specification.name
      ) then
        return nil
      end

      local block_config = merge_block_config(
        config,
        block,
        specification.block_options
      )
      block_config = normalize_config(
        specification.compiler,
        block_config
      )

      local source = block.text

      if specification.compiler.prepare ~= nil then
        source = specification.compiler.prepare(source, block_config)
      end

      local digest = pandoc.utils.sha1(
        cache_identity(source, block_config, specification)
      )

      local contents = cache.get(digest)
      local mime_type

      if contents == nil or block_config.cache == false then
        local compilation

        mime_type, contents, compilation = specification.compiler.compile(
          source,
          block_config
        )

        local cacheable = compilation == nil
          or compilation.cacheable ~= false

        if block_config.cache ~= false and cacheable then
          cache.put(digest, contents)
        end
      else
        mime_type = specification.compiler.mime_type(block_config)
      end

      local media_path = table.concat({
        specification.name,
        "/",
        digest,
        ".",
        tostring(block_config.format)
      })

      return MediaBag.publish(
        block,
        media_path,
        mime_type,
        contents
      )
    end

    return document:walk({ CodeBlock = CodeBlock })
  end

  return {
    { Pandoc = Pandoc }
  }
end

return Engine
