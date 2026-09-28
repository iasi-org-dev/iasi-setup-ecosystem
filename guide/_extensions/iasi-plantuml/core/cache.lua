local Cache = {}

function Cache.open(options)
  local filesystem = options.filesystem
  local directory = options.directory
  local extension = options.extension
  local mode = options.mode

  filesystem.ensure_directory(directory)

  if mode == "clean" then
    filesystem.clean_directory(directory)
    mode = true
  end

  local cache = {}

  function cache.paths(digest)
    return {
      resource = pandoc.path.join({
        directory,
        digest .. "." .. extension
      }),
      marker = pandoc.path.join({
        directory,
        digest .. ".sha1"
      })
    }
  end

  function cache.get(digest)
    if mode ~= true then
      return nil
    end

    local paths = cache.paths(digest)

    if not filesystem.exists(paths.marker)
      or not filesystem.exists(paths.resource)
    then
      return nil
    end

    local stored = filesystem.read(paths.marker):gsub("%s+$", "")

    if stored ~= digest then
      return nil
    end

    return filesystem.read(paths.resource)
  end

  function cache.put(digest, contents)
    if mode ~= true then
      return
    end

    local paths = cache.paths(digest)

    filesystem.write(paths.resource, contents)
    filesystem.write(paths.marker, digest .. "\n")
  end

  return cache
end

return Cache
