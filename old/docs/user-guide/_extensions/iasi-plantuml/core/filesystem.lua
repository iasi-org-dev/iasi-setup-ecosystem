local Filesystem = {}

function Filesystem.ensure_directory(path)
  pandoc.system.make_directory(path, true)
end

function Filesystem.exists(path)
  local file = io.open(path, "rb")

  if file == nil then
    return false
  end

  file:close()
  return true
end

function Filesystem.read(path)
  local file, message = io.open(path, "rb")

  if file == nil then
    error("No se pudo leer " .. path .. ": " .. tostring(message))
  end

  local contents = file:read("*a")
  file:close()

  return contents
end

function Filesystem.write(path, contents)
  Filesystem.ensure_directory(pandoc.path.directory(path))

  local file, message = io.open(path, "wb")

  if file == nil then
    error("No se pudo escribir " .. path .. ": " .. tostring(message))
  end

  file:write(contents)
  file:close()
end

function Filesystem.clean_directory(path)
  Filesystem.ensure_directory(path)

  for _, entry in ipairs(pandoc.system.list_directory(path)) do
    local target = pandoc.path.join({ path, entry })
    local removed, message = os.remove(target)

    if not removed then
      error("No se pudo eliminar " .. target .. ": " .. tostring(message))
    end
  end
end

return Filesystem
